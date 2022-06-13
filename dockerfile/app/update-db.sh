#!/bin/bash -l
export MYSQL_PWD={{MYSQL_PWD}}

DB_HOST={{DB_HOST}}
DB_USER={{DB_USER}}
DB_NAME={{DB_NAME}}

mysql -h ${DB_HOST} -u ${DB_USER} ${DB_NAME} < /root/update-db.sql >> /root/logs/update-db-`date '+%Y%m%d'`.log 2>&1
