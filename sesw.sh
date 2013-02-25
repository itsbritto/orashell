#!/bin/sh
# 
#  queries v$session every 1 second.  fits in the 80-char window.  
# 
#  Usage:
#    sh sesw.sh [> output_file]
#

cd `dirname $0`

LOCKFILE=.lock_sesw_`date "+%m%d%H%M%S"`
rm -f .lock_sesw_*
touch $LOCKFILE
trap "echo terminated; rm -f $LOCKFILE; exit 0" INT

sesw()
{
  echo "connect / as sysdba"
  echo "set pages 9999"
  echo "set lines 200"
  echo "set feedback off"
  echo "set head off"
  while [ -f $LOCKFILE ]
  do
    cat << EOF
col TIME      for a10
col SID       for 9999
col MACHINE   for a15 trunc
col PROGRAM   for a15 trunc
col MODULE    for a15 trunc
col SQL_ID    for a15
col HV        for 99999999999
col COMMAND   for 999
col EVENT     for a30 trunc
col SIW       for 999
col STATE     for a20 trunc

SELECT to_char(sysdate, 'mmddhh24miss') TIME
     , sid
     , machine
     , program
     , module
     , sql_id
     , sql_hash_value hv
     , command
     , event
     , p1
     , p2
     , p3
     , seconds_in_wait SIW
     , state
  FROM v\$session
 WHERE wait_class != 'Idle'
 ORDER BY event, p1;
EOF
    sleep 1
  done
}

sesw | sqlplus -s /nolog

