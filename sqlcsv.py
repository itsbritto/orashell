#!/usr/bin/env python
#
# Run sql against the csv files
#
# Usage:
#   $ sqlcsv.py sql filelist
# 
# Example:
#   $ python sqlcsv.py "select inst_id, sample_time, count(*) from csv where session_type = 'FOREGROUND' group by inst_id, sample_time;" ash*.csv
#   $ python sqlcsv.py "select inst_num, b_h, name, per_second from csv where name like 'Execute%'" load_profile.csv
#
# * you can also specify csv filename as "CSVNAME" column
#
######################################################################################################

import csv
import sys
import sqlite3

sql = sys.argv[1]
conn = sqlite3.connect(':memory:')
conn.row_factory = sqlite3.Row
cursor = conn.cursor()
values = ''

##### fix header text
def head(text):
    for c in [' ','(',')','%','#','$','/']:
        text = text.replace(c, '_')
    return text

##### sys.argv[] filelist does not work in Windows, use glob
filelist = sys.argv[2:]
if filelist[0].find('*') >= 0:
    filelist = glob.glob(filelist[0])

##### iterate over csv files
first_file = True
for filename in filelist:
    sys.stderr.write('Processing {0}...\n'.format(filename))

    ##### create header
    if first_file:
        with open(filename) as f:
            f_csv = csv.reader(f, delimiter=',')
            l_line0 = next(f_csv)  # header
            l_line1 = next(f_csv)  # sample data
            ##### add "CSVNAME" column
            l_types = ['CSVNAME TEXT']
            ##### create "CREATE TABLE" statement
            for i in range(len(l_line0)):
                val = l_line1[i].replace(',', '')
                if val.isdigit():
                    # integer
                    l_types.append(head(l_line0[i]) + ' INTEGER')
                elif val.replace('.', '').isdigit():
                    # float
                    l_types.append(head(l_line0[i]) + ' REAL')
                else:
                    # text
                    l_types.append(head(l_line0[i]) + ' TEXT')
            s_types = ','.join(l_types)
            ##### execute "CREATE TABLE"
            sys.stderr.write('Create: CREATE TABLE csv ({0})\n'.format(s_types))
            cursor.execute('CREATE TABLE csv ({0})'.format(s_types))
            ##### prepare for "INSERT VALUES"
            values = ','.join(['?'] * len(l_types))
            first_file = False

    ##### insert data
    with open(filename) as f:
        f_csv = csv.reader(f, delimiter=',')
        rows = [[filename] + row for row in f_csv][1:]
        sys.stderr.write('Insert: {0} rows.\n'.format(len(rows)))
        cursor.executemany('INSERT INTO csv VALUES ({0})'.format(values), rows)
        conn.commit()

##### execute SQL
first_row = True
cursor.execute(sql)
for row in cursor.fetchall():
    if first_row:
        # display header
        print(','.join(row.keys()))
        first_row = False
    # display data
    print(','.join(str(x) for x in row))
