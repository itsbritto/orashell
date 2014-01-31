orashell
========
various scripts to monitor/administer/analyze Oracle Database.

Language|Name          |Description
--------|--------------|-------------------------------------------------------------------------
bsh     |orashow.sh    |multi-purpose real-time monitoring script
bsh     |getawr.sh     |creates the AWR reports (via Oracle Net)
bsh     |getaddm.sh    |creates the ADDM reports for the last 24 hours
bsh     |sesw.sh       |queries v$session every second
bsh     |sesw9i.sh     |queries v$sessoin/v$session_wait every 5 seconds (9i version)
bsh     |seswsmall.sh  |queries v$session every second, optimized for an 80-char window
bsh     |trace.sh      |sets sql_trace on/off
bsh     |vmstatcsv.sh  |vmstat with timestamp, and output with csv
bash    |oraevents.sh  |queries v$system_events and displays the wait time (as differences)
bash    |orastats.sh   |queries v$sysstat and displays the major stat values (as differences)
python  |sqlcsv.py     |run sql against the csv files