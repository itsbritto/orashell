#!/bin/sh
# 
#  sets sql_trace on/off
# 
#  Usage:
#    sh trace.sh sid level
#      (level = 0(off) / 1(on) / 4(bind) / 8(event) / 12(bind+event))
#

cd `dirname $0`

SID=${1:-"none"}
LVL=${2:-"0"}

WAITS=FALSE
BINDS=FALSE

if [ "$LVL" == "0" ]; then
  sqlplus -s "/ as sysdba" << EOF
    EXEC DBMS_MONITOR.SESSION_TRACE_DISABLE($SID);
    SELECT sid, sql_trace, sql_trace_binds, sql_trace_waits
      FROM v\$session
     WHERE sid = $SID;
EOF
  exit
elif [ "$LVL" == "4" ]; then
  BINDS=TRUE
elif [ "$LVL" == "8" ]; then
  WAITS=TRUE
elif [ "$LVL" == "12" ]; then
  BINDS=TRUE
  WAITS=TRUE
fi

sqlplus -s "/ as sysdba" << EOF
set serveroutput on

VAR inst varchar2(30);
VAR spid NUMBER;
VAR dir VARCHAR2(200);
BEGIN
  SELECT instance_name INTO :inst
    FROM v\$instance;

  SELECT p.spid INTO :spid
    FROM v\$session s, v\$process p
   WHERE s.paddr = p.addr
     AND s.sid = $SID;

  SELECT value INTO :dir
    FROM v\$parameter
   WHERE name = 'user_dump_dest';

  DBMS_MONITOR.SESSION_TRACE_ENABLE($SID, NULL, $WAITS, $BINDS);

  DBMS_OUTPUT.PUT_LINE('Trace: ');
  DBMS_OUTPUT.PUT_LINE(:dir || '/' || :inst || '_ora_' || :spid || '.trc');
END;
/

SELECT sid, sql_trace, sql_trace_binds, sql_trace_waits
  FROM v\$session
 WHERE sid = $SID;

EOF
