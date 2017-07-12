#!/usr/bin/env bash

echo "============================== CHECK REQUIREMENTS =============================="
# Check if script configuration is available
if [ ! -f /vagrant/scripts/provision.cfg ]; then
  echo "ERROR: scripts/provision.cfg not defined. Plase create it using the example provided inside the folder." 1>&2
  exit 1
else
  # Enable custom configuration
  source /vagrant/scripts/provision.cfg
  echo "Everything is checked, proceeding with installation."
fi

echo "============================ INSTALLING NEW SOURCES ============================"
## auto accept oracle license
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections

sudo apt-add-repository ppa:andrei-pozolotin/maven3 -y
sudo add-apt-repository ppa:webupd8team/java -y

sudo apt-get update
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${DB_PASSWORD}"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${DB_PASSWORD}"

echo "=========================== INSTALLING DEPENDENCIES ============================"
sudo apt-get -y --force-yes install oracle-java8-installer oracle-java8-set-default maven3 mysql-server sendmail

echo "============================== DATABASE CREATION ==============================="
if  ! grep -qe "^bind-address = 0.0.0.0" "/etc/mysql/my.cnf"; then
  echo "Updating mysql configs in /etc/mysql/my.cnf."
  sudo sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
    echo "Updated mysql bind address in /etc/mysql/my.cnf to 0.0.0.0 to allow external connections."
    echo "Restarting mysql"
    sudo /etc/init.d/mysql stop
    sudo /etc/init.d/mysql start
    echo "Creating database"
  mysql -u root -p${DB_PASSWORD} -e "CREATE DATABASE ${DB_NAME};"
  mysql -u root -p${DB_PASSWORD} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO 'root'@'%' IDENTIFIED BY '${DB_PASSWORD}' with GRANT OPTION; FLUSH PRIVILEGES;"
fi


echo "========================== ADD ENVIRONMENT VARIABLES ==========================="

if  ! grep -qe "^source /vagrant/scripts/env.cfg" "/home/vagrant/.bashrc"; then
  echo "source /vagrant/scripts/env.cfg" >> /home/vagrant/.bashrc
else
  echo "Environment variables already set."
fi


# Flush changes in file
source /home/vagrant/.bashrc
source ${PROJECT_HOME}/scripts/env.cfg


exec sudo -u vagrant /bin/bash -l << eof
  echo "=========================== CONFIGURING ARTIFACTORY ============================"
  source /home/vagrant/.bashrc
  mkdir /home/vagrant/.m2
  mv /home/vagrant/.m2/settings.xml /home/vagrant/.m2/settings.xml.bkp
  touch /home/vagrant/.m2/settings.xml
  echo "
    <settings>
      <servers>
        <server>
          <id>internal</id>
          <username>${ARTIFACTORY_USER}</username>
          <password>${ARTIFACTORY_PASS}</password>
        </server>
        <server>
          <id>snapshot</id>
          <username>${ARTIFACTORY_USER}</username>
          <password>${ARTIFACTORY_PASS}</password>
        </server>
      </servers>
  </settings>
  " >> /home/vagrant/.m2/settings.xml

  echo "============================== BUILDING PROJECT ================================"
  cd ${PROJECT_HOME}
  mvn clean package

  echo "Checking if the project was built..."
  if ! ls ${PROJECT_HOME}/target/middleware-*.jar; then
    echo "ERROR: Build command failed, please start the virtual machine and run \"build\" command, after that run
    \"migrate\" command."
    exit 1
  else
    echo "============================ INSTALLING DATABASE ==============================="
    java -jar ${PROJECT_HOME}/target/middleware-*.jar db migrate config/config.yml
  fi

eof
