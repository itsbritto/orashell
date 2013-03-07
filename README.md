orashell
========
Oracle DB related shell scripts.

* getaddm.sh - creates the ADDM reports for the last 24 hours
* getawr.sh - creates the AWR reports for the last 24 hours
* oraevents.sh - queries v$system_events and displays the wait time (as differences)
* orashow.sh - multi-purpose real-time monitoring script, for performance testing phase
* orastats.sh - queries v$sysstat and displays the major stat values (as differences)
* sesw.sh - queries v$session every second
* sesw9i.sh - queries v$sessoin/v$session_wait every 5 seconds (9i version)
* seswsmall.sh - queries v$session every second, optimized for an 80-char window
* trace.sh - sets sql_trace on/off
* vmstatcsv.sh - vmstat with timestamp, and output with csv
