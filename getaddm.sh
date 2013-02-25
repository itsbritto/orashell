#!/bin/sh
#
#  creates the ADDM reports for the last 24 hours
#

INSTANCES=4
ORALOGIN="/ as sysdba"
export NLS_LANG=American_America.US7ASCII

for inst in `seq 1 $INSTANCES`
do
  # list of the snap_ids within the specified range
  sqlplus -s $ORALOGIN << EOF > sql1.log
    whenever sqlerror exit rollback;
    whenever oserror exit rollback;
    set head off newpage none feedback off echo off
    select dbid, snap_id from dba_hist_snapshot
     where instance_number = $inst
       and begin_interval_time > (sysdate - 1)
     order by begin_interval_time asc;
    exit;
EOF
  i=1
  lastid=`head -1 sql1.log | awk '{print $2}'`
  cat sql1.log | while read dbid snapid
  do
    if [ $i -eq 0 ]
    then
      echo "creating ADDM_${inst}_${lastid}.txt..."
      sqlplus -s $ORALOGIN << EOF > /dev/null
        whenever sqlerror exit rollback;
        whenever oserror exit rollback;
        set head off newpage none feedback off echo off trimspool on trimout on
        set lines 1000 pages 50000 arraysize 1000 long 1000000 longchunksize 1000
        -- ADDM
        variable task_name varchar2(40);
        declare
          id number;
          name varchar2(100);
        begin
           name := '';
           dbms_advisor.create_task('ADDM',id,name,'ADDM'||$lastid||'-'||$snapid,null);
           :task_name := name;
           dbms_advisor.set_task_parameter(name, 'DB_ID', $dbid);
           dbms_advisor.set_task_parameter(name, 'INSTANCE', $inst);
           dbms_advisor.set_task_parameter(name, 'START_SNAPSHOT', $lastid);
           dbms_advisor.set_task_parameter(name, 'END_SNAPSHOT', $snapid);
           dbms_advisor.execute_task(name);
        end;
        /
        column get_clob format a80
        spool ADDM_${inst}_${lastid}.txt
        select dbms_advisor.get_task_report(:task_name, 'TEXT', 'TYPICAL')
          from dual;
        spool off
        execute dbms_advisor.delete_task(:task_name);
        exit
EOF
      i=1
      lastid=$snapid
    fi
    i=`expr $i - 1`
  done
done
rm -f sql?.log

