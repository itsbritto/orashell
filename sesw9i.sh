#!/bin/sh
#
#  queries v$sessoin/v$session_wait every 5 seconds (9i version)
# 
#  Usage:
#    sh sesw9i.sh [> output_file]
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
  while [ -f $LOCKFILE ]
  do
    cat << EOF
col TIME      for a10
col SID       for 99999
col PROGRAM   for a25 trunc
col MODULE    for a25 trunc
col EVENT     for a30 trunc
col SIW       for 9999

SELECT to_char(sysdate, 'mmddhh24miss') TIME
     , s.sid
--     , ss.program
     , ss.module
     , ss.sql_hash_value
     , s.event
     , s.p1
     , s.p2
     , s.p3
     , s.seconds_in_wait siw
  FROM v\$session_wait s
     , v\$session ss
 WHERE s.sid = ss.sid
   AND s.event NOT IN
       (
         'client message'
        ,'rdbms ipc message'
        ,'Null event'
        ,'null event'
        ,'wakeup time manager'
        ,'pipe get'
        ,'pmon timer'
        ,'queue messages'
        ,'gcs remote message'
        ,'ges remote message'
        ,'Queue Monitor Wait'
       )
   AND s.event not like 'SQL*Net%'
 ORDER BY s.event, s.p1;

EOF
    sleep 5
  done
}

sesw | sqlplus -s /nolog

