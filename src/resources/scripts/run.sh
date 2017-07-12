#!/usr/bin/env bash

cd $PROJECT_HOME
NFR_BUILD_EXP="target/nfreports-*.jar"

echo "Checking if the project was built..."

if ! ls ${NFR_BUILD_EXP}; then
  echo "Please, compile the project with \"build\" command first."
else
  NFR_BUILD_FILE=`ls ${NFR_BUILD_EXP}`
  DEBUG_CONFIG="-Xdebug -agentlib:jdwp=transport=dt_socket,address=9999,server=y,suspend=n"
  java ${DEBUG_CONFIG} -jar ${NFR_BUILD_FILE} server config/config.yml
fi
