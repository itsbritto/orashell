#!/bin/sh
#
#  create CSV file from the vmstat log
#
#  Usage:
#    sh vmstat2csv.sh vmstat_log
#
#  Expects vmstat log with a timestamp.
#  "vmstat -t .." or "vmstat .. | awk '{t=strftime("%Y-%m-%d %T %Z"); print $0, t}'"
# 
#  procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu------ ---timestamp---
#   r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
#   0  0      0 400488   7868  43488    0    0    28     1   37   35  1  2 97  0  0        2012-07-01 11:44:40 JST
#   0  0      0 400488   7868  43488    0    0     0     0   12   12  0  0 100  0  0       2012-07-01 11:44:41 JST
#   0  0      0 400488   7868  43488    0    0     0     0    7    8  0  0 100  0  0       2012-07-01 11:44:42 JST
#  
#  Above turns into
#
#  r,b,swpd,free,buff,cache,si,so,bi,bo,in,cs,us,sy,id,wa,st,Y,M,D,HH,MM,SS
#  0,0,0,400488,7868,43488,0,0,28,1,37,35,1,2,97,0,0,2012,07,01,11,44,40
#  0,0,0,400488,7868,43488,0,0,0,0,12,12,0,0,100,0,0,2012,07,01,11,44,41
#  0,0,0,400488,7868,43488,0,0,0,0,7,8,0,0,100,0,0,2012,07,01,11,44,42

INFILE=$1

# header
grep swpd vmstat.log | head -1 | sed -e "s/  */\,/g" -e "s/^,//" | awk '{OFS=",";print $0,"Y,M,D,HH,MM,SS"}'

# contents
grep -e "$[T]" vmstat.log | sed -e "s/  */\,/g" -e "s/[\t|:|\\-]/\,/g" -e "s/^,//" -e "s/,[A-Z]*T//"


