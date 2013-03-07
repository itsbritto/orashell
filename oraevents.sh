#!/bin/bash
#
#  queries v$system_events and display the wait time (as differences)
#
################################################################################
#ENV
PG=`basename $0`
TMP1=.oraevents_`date +%s`_1.log
export NLS_LANG=American_America.AL32UTF8
trap "echo terminated; rm -f $TMP1; exit 0" INT

LOGIN=${1:-"none"}
INTV=${2:-"5"}
OUTFILE=${3:-"/dev/null"}

################################################################################
# HELP
if [ "$LOGIN" = "none" ]
then
  cat << EOF
  Usage: $PG login_str interval [output_file]
EOF
  rm -f $TMP1
  exit 0
fi

################################################################################
# initialize array
declare -A currvals
declare -A lastvals

# exec
echo "INFO: Type Ctrl+C to exit."
touch $TMP1
{
  echo "whenever sqlerror exit rollback;"
  echo "whenever oserror exit rollback;"
  echo "set head off"
  echo "set newpage none"
  echo "set feedback off"
  echo "set echo off"
  echo "set lines 200"
  echo "set pages 50000"
  echo "set trimspool on"
  echo "set trimout on"
  echo "set arraysize 1000"
  echo "col event for a100"
  echo "col wait_time for 999999999999999999999"
  while [ -f $TMP1 ]
  do
    cat << EOF
  SELECT TO_CHAR(sysdate,'YYYYMMDDHH24MISS') datetime
       , REPLACE(event,' ','_') event
       , ROUND(time_waited_micro_fg/1000000,0) wait_time
    FROM v\$system_event
   WHERE wait_class != 'Idle'
     AND time_waited_fg > 0
   ORDER BY event;
EOF
    sleep $INTV
  done
} | sqlplus -s $LOGIN | while read datetime name value
do
  currvals["$name"]=$(($value-${lastvals["$name"]:-0}))
  lastvals["$name"]=$value
  if [ ${currvals["$name"]} -gt 0 ]
  then
    echo $datetime,$name,${currvals["$name"]} | tee -a $OUTFILE
  fi
done

################################################################################
# CLEANUP
rm -f $TMP1
exit 0

