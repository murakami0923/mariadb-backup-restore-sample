#!/bin/bash

until mysqladmin ping -h ${DB_HOST} --silent; do
  echo 'waiting for mysqld to be connectable...' >> /root/init-db.log 2>&1
  sleep 2
done

mysql -h ${DB_HOST} -u ${DB_USER} ${DB_NAME} < /root/init-db.sql >> /root/init-db.log 2>&1

echo 'init database completed.' >> /root/init-db.log 2>&1
