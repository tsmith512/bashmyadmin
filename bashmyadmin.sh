#!/bin/bash

############################################################
# Parse Arguments and Flags                                #
############################################################

SCRIPT_DIR="$(dirname $0)"
WORKING_DIR="$(pwd)"

GLOBALS="globals.sh"
PROFILE=""
PROFILEX=""
COMMAND=""
SQLFILE=""

while getopts "p:c:f:x:" option; do
  case "${option}" in
  p)
    PROFILE="${OPTARG}"
    [ "${PROFILE/#\//}" != "$PROFILE" ] || PROFILE="$WORKING_DIR/$PROFILE"
    ;;
  x)
    PROFILEX="${OPTARG}"
    [ "${PROFILEX/#\//}" != "$PROFILEX" ] || PROFILEX="$WORKING_DIR/$PROFILEX"
    ;;
  c)
    COMMAND="${OPTARG}"
    ;;
  f)
    SQLFILE="${OPTARG}"
    [ "${SQLFILE/#\//}" != "$SQLFILE" ] || SQLFILE="$WORKING_DIR/$SQLFILE"
    ;;
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

source $SCRIPT_DIR/$GLOBALS > /dev/null 2>&1 || {
  echo >&2 "Global configuration file not available.";
  exit 1;
}

source $PROFILE > /dev/null 2>&1 || {
  echo >&2 "Config file not found at: ${PROFILE}";
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
        TO ${DB_USER}@'localhost' IDENTIFIED BY '${DB_PASS}';
    ";;

  drop)
    read -p "Are you sure you want to drop ${DB_NAME} (y/n)? "
    [ "$REPLY" != "y" ] || {
      mysql --user="${SU_USER}" --password=$SU_PASS --host=$DB_HOST -e "
        DROP DATABASE ${DB_NAME};
      ";
    }
    read -p "Also drop user ${DB_USER} (y/n)? "
    [ "$REPLY" != "y" ] || {
      mysql --user="${SU_USER}" --password=$SU_PASS --host=$DB_HOST -e "
        DROP USER ${DB_USER}@'localhost'
      ";
    }
    ;;

  dump)
    if [ -z "$SQLFILE" ]; then
      echo >&2 "Dump requires a filename."
      exit 1;
    fi

    echo "Dumping ${DB_NAME} to file."
    mysqldump --user="${DB_USER}" --password=$DB_PASS --host=$DB_HOST ${DB_NAME} \
      --add-drop-table > $SQLFILE
    ;;

  read)
    if [ -z "$SQLFILE" ]; then
      echo >&2 "Read requires a filename."
      exit 1;
    fi

    echo "Reading ${SQLFILE} to ${DB_NAME}."
    mysql --user="${DB_USER}" --password=$DB_PASS --host=$DB_HOST ${DB_NAME} \
      < $SQLFILE
    ;;

  xfer)
    if [ -z "$PROFILEX" ]; then
      echo >&2 "Destination profile not specified."
      exit 1;
    fi
    TEMP=$(date | md5sum | head -c25)
    $0 -p $PROFILE -c dump -f $TMP_DIR/$TEMP.sql
    $0 -p $PROFILEX -c read -f $TMP_DIR/$TEMP.sql
    rm $TMP_DIR/$TEMP.sql
esac