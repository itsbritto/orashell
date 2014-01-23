#!/bin/sh
#
#  creates the AWR reports
#     $ sh getawr.sh "sys/xxxx@host:1521/db as sysdba" local 5
#          awr_<inst_id>_<snap_id>_<snap_id>.html
#               :
#
################################################################################
#ENV
FORMAT=html
PG=`basename $0`
export NLS_LANG=American_America.AL32UTF8

LOGIN=${1:-"none"}
OPT=${2:-"local"}
HOURS=${3:-"24"}

################################################################################
# HELP
if [ "$LOGIN" = "none" ]
then
  cat << EOF
  Usage: $PG login_str [local|global] [hours]
EOF
  exit 0
fi

################################################################################
# list snap ids
sqlplus -s $LOGIN << EOF > sql1.log
  whenever sqlerror exit rollback;
  whenever oserror exit rollback;
  set head off newpage none feedback off echo off
  select dbid, snap_id from dba_hist_snapshot
   where instance_number = 1
     and begin_interval_time > (sysdate - $HOURS/24)
   order by begin_interval_time asc;
  exit
EOF

################################################################################
# create report
if [ "$OPT" = "local" ]
then
  # local
  sqlplus -s $LOGIN << EOF > sql2.log
    whenever sqlerror exit rollback;
    whenever oserror exit rollback;
    set head off newpage none feedback off echo off
    select max(thread#) from v\$log;
    exit
EOF
  INSTANCES=`head -1 sql2.log | awk '{print $1}'`
  for inst in `seq 1 $INSTANCES`
  do
    lastid=null
    cat sql1.log | while read dbid snapid
    do
      if [ "$lastid" != "null" ]
      then
          echo "creating awr_${inst}_${lastid}_${snapid}.$FORMAT..."
          sqlplus -s $LOGIN << EOF > /dev/null
            whenever sqlerror exit rollback;
            whenever oserror exit rollback;
            set head off newpage none feedback off echo off trimspool on trimout on
            set lines 1000 pages 50000 arraysize 1000 long 1000000 longchunksize 1000
            spool awr_${inst}_${lastid}_${snapid}.$FORMAT
            select output from table(dbms_workload_repository.awr_report_$FORMAT($dbid, $inst, $lastid, $snapid));
            spool off
            exit
EOF
      fi
      lastid=$snapid
    done
  done
else
  # global
  lastid=null
  cat sql1.log | while read dbid snapid
  do
    if [ "$lastid" != "null" ]
    then
        echo "creating awr_g_${lastid}_${snapid}.$FORMAT..."
        sqlplus -s $LOGIN << EOF > /dev/null
          whenever sqlerror exit rollback;
          whenever oserror exit rollback;
          set head off newpage none feedback off echo off trimspool on trimout on
          set lines 1000 pages 50000 arraysize 1000 long 1000000 longchunksize 1000
          spool awr_g_${lastid}_${snapid}.$FORMAT
          select output from table(dbms_workload_repository.awr_global_report_$FORMAT($dbid, '', $lastid, $snapid));
          spool off
          exit
EOF
    fi
    lastid=$snapid
  done
fi

rm -f sql?.log

