#!/bin/bash -l
export MYSQL_PWD={{MYSQL_PWD}}

DB_HOST={{DB_HOST}}
DB_USER={{DB_USER}}
DB_NAME={{DB_NAME}}

shuf=`shuf -i 1-100000000 -n 1`; name_sum=`echo -n ${shuf} | sha256sum `
created_at=`date '+%Y-%m-%d %H:%M:%S'`

sql="INSERT INTO test_data (name, created_at) VALUES ('${name_sum}', '${created_at}');"
echo ${sql} >> /root/logs/update-db-`date '+%Y%m%d'`.log 2>&1

mysql -h ${DB_HOST} -u ${DB_USER} ${DB_NAME} -e "${sql}" >> /root/logs/update-db-`date '+%Y%m%d'`.log 2>&1

# mysql -h ${DB_HOST} -u ${DB_USER} ${DB_NAME} < /root/update-db.sql >> /root/logs/update-db-`date '+%Y%m%d'`.log 2>&1
