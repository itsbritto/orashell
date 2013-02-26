#!/bin/sh
# 
#  queries v$session every second, optimized for 80-char window
# 
#  Usage:
#    sh seswsmall.sh [> output_file]
#

cd `dirname $0`

LOCKFILE=.lock_seswsmall_`date "+%m%d%H%M%S"`
rm -f .lock_seswsmall_*
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
col TIME      for a6
col SID       for 9999
col SQL_ID    for a15
col MODULE    for a12 trunc
col EVENT     for a20 trunc
col P1P2      for a12 trunc
col SIW       for 999

SELECT to_char(sysdate, 'hh24miss') TIME
     , sid
     , module
     , sql_id
     , event
     , p1||','||p2 p1p2
     , seconds_in_wait siw
  FROM v\$session
 WHERE wait_class != 'Idle'
 ORDER BY event;
EOF
    sleep 1
  done
}

sesw | sqlplus -s /nolog

