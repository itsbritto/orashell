#!/bin/sh
#
#  benri shell
#  Updated: 12/20/2012
#
################################################################################
#ENV
PG=`basename $0`
OP=${1:-"none"}
LOGIN="/ as sysdba"
TMP1=.orashow_`date +%s`_1.log
TMP2=.orashow_`date +%s`_2.log
TMP3=.orashow_`date +%s`_3.log
export NLS_LANG=American_America.AL32UTF8
trap "echo terminated; rm -f $TMP1; rm -f $TMP2; rm -f $TMP3; exit 0" INT

################################################################################
# HELP
if [ "$OP" = "none" ]
then
  cat << EOF

  Usage: $PG <command>

  Commands:
      - ash  <minutes_from_now>     display ASH report (default: 5)
      - ashg <minutes_from_now>     display global ASH report (default: 5)
      - plan <sql_id>               get explain plan of a cursor
      - text <sql_id>               get sql text of a cursor
      - tbs                         list tablespace sizes
      - params                      list non-default parameters
      - index <owner> <table>       list indexes for a table
      - part <owner> <table>        list partition info for a table
      - monitor                     list sql monitor
      - monitor <sql_id>            list sql report for a sql
      - sessions                    list sessions (global)
      - seswait <interval_sec>      v\$session every n seconds (default: 5)

EOF
fi

################################################################################
# ASH REPORT
if [ "$OP" = "ash" ] || [ "$OP" = "ashg" ]
then
  # get duration
  DUR=${2:-"none"}
  if [ "$DUR" = "none" ]
  then
    echo "INFO: Using default duration of 5 minutes."
    DUR=5
  fi
  # get dbid, instance_number
  sqlplus -s $LOGIN << EOF > $TMP1
    whenever sqlerror exit rollback;
    whenever oserror exit rollback;
    set head off
    set newpage none
    set feedback off
    set echo off
    SELECT dbid, instance_number FROM v\$database, v\$instance;
    exit
EOF
  DBID=`head -1 $TMP1 | awk '{print $1}'`
  # get function name
  if [ "$OP" = "ash" ]
  then
    FUNC=ash_report_text
    INSTID=`head -1 $TMP1 | awk '{print $2}'`
  else
    FUNC=ash_global_report_text
    INSTID=NULL
  fi
  # exec
  sqlplus -s $LOGIN << EOF
    whenever sqlerror exit rollback;
    whenever oserror exit rollback;
    set head off
    set newpage none
    set feedback off
    set echo off
    set lines 80
    set pages 50000
    set trimspool on
    set trimout on
    set arraysize 1000
    SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.$FUNC($DBID, $INSTID, SYSDATE-$DUR/60/24, SYSDATE));
    exit
EOF
fi

################################################################################
# SQLPLAN
if [ "$OP" = "plan" ]
then
  SQLID=${2:-"none"}
  if [ "$SQLID" = "none" ]
  then
    echo "WARN: SQL_ID is missing."
  else
    CNUM=0  # for now
    sqlplus -s $LOGIN << EOF
      whenever sqlerror exit rollback;
      whenever oserror exit rollback;
      set head off
      set newpage none
      set feedback off
      set echo off
      set lines 180
      set pages 50000
      set trimspool on
      set trimout on
      set arraysize 1000
      SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('$SQLID', 0));
      exit
EOF
  fi
fi

################################################################################
# TEXT
if [ "$OP" = "text" ]
then
  SQLID=${2:-"none"}
  if [ "$SQLID" = "none" ]
  then
    echo "WARN: SQL_ID is missing."
  else
    sqlplus -s $LOGIN << EOF
      whenever sqlerror exit rollback;
      whenever oserror exit rollback;
      set newpage none
      set feedback off
      set echo off
      set lines 180
      set pages 50000
      set trimspool on
      set trimout on
      set arraysize 1000
      SELECT sql_text FROM v\$sqltext_with_newlines WHERE sql_id = '$SQLID' ORDER BY piece;
      exit
EOF
  fi
fi

################################################################################
# TABLESPACE SIZE
if [ "$OP" = "tbs" ]
then
  sqlplus -s $LOGIN << EOF | egrep -v "no rows selected|Session altered|Connected|rows selected"
    whenever sqlerror exit rollback;
    whenever oserror exit rollback;
    set lines 80
    set pages 9999
    SELECT ts.tablespace_name
         , ts.total_space_mb
         , NVL(fs.free_space_mb, 0) "FREE_SPACE(MB)"
         , NVL(ROUND(100*fs.free_space_mb/ts.total_space_mb), 0) "FREE_SPACE(%)"
      FROM (SELECT tablespace_name
                 , ROUND(SUM(bytes)/1024/1024) total_space_mb
              FROM dba_data_files
             GROUP BY tablespace_name) ts
         , (SELECT tablespace_name
                 , ROUND(SUM(bytes)/1024/1024) free_space_mb
              FROM dba_free_space
             GROUP BY tablespace_name) fs
     WHERE ts.tablespace_name = fs.tablespace_name(+)
     ORDER BY ts.tablespace_name;
    exit
EOF
fi

################################################################################
# INIT PARAMETERS
if [ "$OP" = "params" ]
then
  sqlplus -s $LOGIN << EOF | egrep -v "no rows selected|Session altered|Connected|rows selected"
    whenever sqlerror exit rollback;
    whenever oserror exit rollback;
    set lines 180
    set pages 9999
    col name for a30
    col value for a50 trunc
    col description for a50 trunc
    col sess_mod for a8
    col sys_mod for a9
    SELECT a.ksppinm  NAME
         , b.ksppstvl VALUE
         , a.ksppdesc DESCRIPTION
         , DECODE(BITAND(a.ksppiflg / 256, 1), 1, 'TRUE', 'FALSE') SESS_MOD
         , DECODE(BITAND(a.ksppiflg / 65536, 3), 1, 'IMMEDIATE', 2, 'DEFERRED', 3, 'IMMEDIATE', 'FALSE') SYS_MOD
      FROM x\$ksppi a
         , x\$ksppsv b
     WHERE a.indx = b.indx
       AND b.ksppstdf = 'FALSE'
     ORDER BY 1
    ;
    exit
EOF
fi

################################################################################
# INDEXES
if [ "$OP" = "index" ]
then
  OWNER=${2:-"none"}
  TABLE=${3:-"none"}
  if [ "$OWNER" = "none" ] || [ "$TABLE" = "none" ]
  then
    echo "WARN: owner and/or table is missing."
  else
    sqlplus -s $LOGIN << EOF | egrep -v "no rows selected|Session altered|Connected|rows selected"
      whenever sqlerror exit rollback;
      whenever oserror exit rollback;
      set lines 180
      set pages 9999
      set feedback off
      col u for a1
      col type for a6 trunc
      col index_name for a30
      col column_name for a30
      break -
        on table_name - 
        on u -
        on type -
        on index_name -

      SELECT c.table_name
           , DECODE(i.uniqueness, 'UNIQUE', 'Y', 'N') u
           , DECODE(i.index_type, 'NORMAL', '', i.index_type) type
           , c.index_name
           , c.column_name
        FROM all_ind_columns c
           , all_indexes i
       WHERE c.table_owner = i.table_owner
         AND c.index_name = i.index_name
         AND i.table_owner = UPPER('$OWNER')
         AND i.table_name = UPPER('$TABLE')
       ORDER BY c.table_name, c.index_name, c.column_position;
      exit
EOF
  fi
fi

################################################################################
# PARTITION INFO
if [ "$OP" = "part" ]
then
  OWNER=${2:-"none"}
  TABLE=${3:-"none"}
  if [ "$OWNER" = "none" ] || [ "$TABLE" = "none" ]
  then
    echo "WARN: owner and/or table is missing."
  else
    sqlplus -s $LOGIN << EOF | egrep -v "no rows selected|Session altered|Connected|rows selected"
      whenever sqlerror exit rollback;
      whenever oserror exit rollback;
      set lines 180
      set pages 9999
      col column_name for a50 trunc
      SELECT table_name, partitioning_type
           , subpartitioning_type, partition_count
        FROM all_part_tables
       WHERE owner = UPPER('$OWNER')
         AND table_name = UPPER('$TABLE');
      SELECT index_name, partitioning_type
           , subpartitioning_type, partition_count, locality, alignment
        FROM all_part_indexes
       WHERE owner = UPPER('$OWNER')
         AND table_name = UPPER('$TABLE');
      SELECT p.name, p.object_type
           , DECODE(s.column_name,NULL,p.column_name,p.column_name||'/'||s.column_name) column_name
        FROM all_part_key_columns p
           , all_subpart_key_columns s
       WHERE p.name = s.name(+)
         AND p.owner = UPPER('$OWNER')
         AND p.name = UPPER('$TABLE');
      exit
EOF
  fi
fi
# drop table testp purge;
# create table testp (col1 number not null, col2 number not null, col3 number)
# partition by hash (col1) partitions 4;
# create unique index testp_pk on testp (col1, col2) local;
# alter table testp add primary key (col1, col2) using index local;

################################################################################
# SQL MONITOR
if [ "$OP" = "monitor" ]
then
  SQLID=${2:-"none"}
  if [ "$SQLID" = "none" ]
  then
    # monitor list
    sqlplus -s $LOGIN << EOF | egrep -v "no rows selected|Session altered|Connected|rows selected"
      whenever sqlerror exit rollback;
      whenever oserror exit rollback;
      set lines 180
      set pages 9999
      set feedback off
      col sql_text for a80 wrap
      SELECT sql_id
           , TO_CHAR(sql_exec_start, 'HH24:MI:SS') started
           , status
           , ROUND(elapsed_time/1000000) "ELAPSED(s)"
           , ROUND(cpu_time/1000000) "CPU(s)"
           , sql_text
        FROM v\$sql_monitor
       WHERE px_server# is null
       ORDER BY sql_exec_start;
      exit
EOF
  else
    # for particular sql
    sqlplus -s $LOGIN << EOF | egrep -v "no rows selected|Session altered|Connected|rows selected"
      whenever sqlerror exit rollback;
      whenever oserror exit rollback;
      set lines 400
      set pages 9999
      set long 2000000
      set longchunksize 2000000
      set trimout on
      set head off
      SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(report_level=>'+histogram', sql_id=>'$SQLID') monitor_report FROM dual;
      exit
EOF
  fi
fi

################################################################################
# V$SESSION
if [ "$OP" = "sessions" ]
then
  sqlplus -s $LOGIN << EOF | egrep -v "no rows selected|Session altered|Connected|rows selected"
    whenever sqlerror exit rollback;
    whenever oserror exit rollback;
    set lines 180
    set pages 9999
    set feedback off
    col "I#" for 99
    col sid for 999
    col "S#" for 99999
    col spid for a6
    col machine for a20 trunc
    col program for a20 trunc
    col module for a20 trunc
    col username for a15 trunc
    col action for a15 trunc
    SELECT s.inst_id i#
         , s.sid
         , s.serial# s#
         , p.spid
         , s.type
         , s.machine
         , REPLACE(s.program, s.machine, '<HOST>') program
         , s.module
         , s.username
         , a.name action
         , s.status
         , TO_CHAR(s.logon_time, 'YYYY/MM/DD HH24:MI:SS') logon_time
      FROM gv\$session s, gv\$process p, audit_actions a
     WHERE s.inst_id = p.inst_id(+)
       AND s.paddr = p.addr(+)
       AND s.command = a.action(+)
     ORDER BY 1, 2;
    exit
EOF
fi

################################################################################
# V$SESSION (EVENTS)
if [ "$OP" = "seswait" ]
then
  # get interval
  INTV=${2:-"none"}
  if [ "$INTV" = "none" ]
  then
    echo "INFO: Using default interval of 5 seconds."
    INTV=5
  fi
  # exec
  echo "INFO: Type Ctrl+C to exit."
  touch $TMP1
  {
    echo "set lines 200"
    echo "set pages 9999"
    echo "set feedback off"
    while [ -f $TMP1 ]
    do
      cat << EOF
        col time      for a10
        col sid       for 9999
        col machine   for a15 trunc
        col program   for a10 trunc
        col module    for a10 trunc
        col sql_id    for a15
        col cmd       for 999
        col event     for a30 trunc
        col siw       for 999
        col state     for a20 trunc
        SELECT TO_CHAR(SYSDATE, 'MMDDHH24MISS') time
             , sid
             , machine
             , program
             , module
             , sql_id
             , command cmd
             , event
             , p1
             , p2
             , p3
             , seconds_in_wait siw
             , state
          FROM v\$session
         WHERE wait_class != 'Idle'
         ORDER BY event, p1;
EOF
      sleep $INTV
    done
  } | sqlplus -s $LOGIN
fi

################################################################################
# CLEANUP
rm -f $TMP1
rm -f $TMP2
rm -f $TMP3
exit 0
