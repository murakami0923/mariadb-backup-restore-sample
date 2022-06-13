#!/bin/bash

# 初期テーブル作成
/root/init-db.sh

# DB更新用シェルスクリプトの環境変数を記載
# ※cronでは環境変数が反映されないため
sed -i -r "s/\\{\\{MYSQL_PWD\\}\\}/${MYSQL_PWD}/g" /root/update-db.sh
sed -i -r "s/\\{\\{DB_HOST\\}\\}/${DB_HOST}/g" /root/update-db.sh
sed -i -r "s/\\{\\{DB_USER\\}\\}/${DB_USER}/g" /root/update-db.sh
sed -i -r "s/\\{\\{DB_NAME\\}\\}/${DB_NAME}/g" /root/update-db.sh

# cronを起動
service cron start

# cronの設定を反映
crontab < /root/cron

# exec /sbin/init

# コンテナが常に起動しているようにする
while true
do
sleep 10
done