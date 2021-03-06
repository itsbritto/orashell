#!/bin/bash
#
#  queries v$sysstat and display the major stat values (as differences)
#
################################################################################
#ENV
PG=`basename $0`
TMP1=.orastats_`date +%s`_1.log
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
  echo "col name for a100"
  echo "col value for 999999999999999999999"
  while [ -f $TMP1 ]
  do
    cat << EOF
  SELECT TO_CHAR(sysdate,'YYYYMMDDHH24MISS') datetime
       , REPLACE(n.name,' ','_') name
       , s.value
    FROM v\$statname n, v\$sysstat s
   WHERE n.statistic# = s.statistic#
     AND n.name in ('CPU used by this session'
                   ,'execute count'
                   ,'redo size'
                   )
   ORDER BY n.name;
EOF
    sleep $INTV
  done
} | sqlplus -s $LOGIN | while read datetime name value
do
  currvals["$name"]=$(($value-${lastvals["$name"]:-0}))
  lastvals["$name"]=$value
  echo $datetime,$name,${currvals["$name"]} | tee -a $OUTFILE
done

################################################################################
# CLEANUP
rm -f $TMP1
exit 0

