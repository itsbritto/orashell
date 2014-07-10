orashell
========
various scripts to monitor/analyze Oracle Database performance

Language|Name          |Description
--------|--------------|-------------------------------------------------------------------------
sh      |orashow.sh    |multi-purpose real-time monitoring script
sh      |getawr.sh     |creates the AWR reports (via Oracle Net)
sh      |getaddm.sh    |creates the ADDM reports for the last 24 hours
sh      |sesw.sh       |queries v$session every second
sh      |sesw9i.sh     |queries v$sessoin/v$session_wait every 5 seconds (9i version)
sh      |seswsmall.sh  |queries v$session every second, optimized for an 80-char window
sh      |trace.sh      |sets sql_trace on/off
sh      |vmstatcsv.sh  |vmstat with timestamp, and output with csv
bash4-  |oraevents.sh  |queries v$system_events and displays the wait time (as differences)
bash4-  |orastats.sh   |queries v$sysstat and displays the major stat values (as differences)
