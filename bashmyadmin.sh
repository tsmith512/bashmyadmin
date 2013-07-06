#!/bin/bash

############################################################
# Parse Arguments and Flags                                #
############################################################

GLOBALS="globals.sh"
PROFILE=""
COMMAND=""
SQLFILE=""

while getopts "p:c:f:" option; do
  case "${option}" in
  p) PROFILE="${OPTARG}.sh";;
  c) COMMAND="${OPTARG}";;
  f) SQLFILE="${OPTARG}";;
  esac
done

############################################################
# Check for our requirements                               #
############################################################

declare -a deps=(mysql mysqldump)

for i in ${deps[@]}; do
  type -P $i >/dev/null 2>&1 || { 
    echo >&2 "${i} not available. Aborting.";
    exit 1;
  }
done

if [ -z "$PROFILE" ]; then
  echo >&2 "Profile not specified."
  exit 1;
fi

if [ -z "$COMMAND" ]; then
  echo >&2 "Command not specified."
  exit 1;
fi

source $GLOBALS > /dev/null 2>&1 || {
  echo >&2 "Global configuration file not available.";
  exit 1;
}

source ${0%/*}/$PROFILE > /dev/null 2>&1 || {
  echo >&2 "Config file not found at: ${0%/*}/${PROFILE}";
  exit 1;
}

############################################################
# Do stuff                                                 #
############################################################

case "$COMMAND" in
  create)
    echo "Creating ${DB_NAME} as ${SU_USER} and assigning privileges to ${DB_USER}."
    mysql --user="${SU_USER}" --password=$SU_PASS --host=$DB_HOST -e "
      CREATE DATABASE ${DB_NAME};
      GRANT ALL PRIVILEGES ON ${DB_NAME}.*
        TO ${DB_USER}@localhost IDENTIFIED BY '${DB_PASS}';
    ";;

  dump)
    echo "Dumping ${DB_NAME} to file."
    mysqldump --user="${SU_USER}" --password=$SU_PASS --host=$DB_HOST ${DB_NAME} \
      --add-drop-table > $SQLFILE
    ;;
esac