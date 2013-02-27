#!/bin/sh
#
# vmstat with timestamp, and output with csv
#
# Usage:
#   $ sh vmstatcsv.sh <vmstat args>
#
# Caution: below will cause buffering, and ctrl+c will cause a broken row.
#   $ sh vmstatcsv.sh 1 > test.csv
#

vmstat | grep swpd | awk '{OFS=""; gsub(/  */,",",$0); print "datetime",$0}'
vmstat $* | egrep --line-buffered -v "procs|swpd" | awk '{OFS=""; t=strftime("%Y%m%d%H%M%S"); gsub(/  */,",",$0); print t,$0}'
