FROM ubuntu:22.04

RUN apt update
RUN apt upgrade -y
RUN apt install -y cron
RUN apt install -y vim
RUN apt install -y less
RUN apt install -y mysql-client

# ロケール
RUN apt install -y language-pack-ja-base language-pack-ja locales
RUN locale-gen ja_JP.UTF-8

ENV LANG ja_JP.UTF-8
ENV LANGUAGE ja_JP:ja
ENV LC_ALL ja_JP.UTF-8

# タイムゾーン
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y tzdata
# timezone setting
ENV TZ=Asia/Tokyo 

# アプリケーション用SQL、bash、cron
COPY init-db.sh /root/
RUN chmod a+x /root/init-db.sh
COPY init-db.sql /root/

COPY update-db.sh /root/
RUN chmod a+x /root/update-db.sh
COPY cron /root/

COPY startup.sh /root/
RUN chmod a+x /root/startup.sh

RUN mkdir /root/logs/

ENTRYPOINT "/root/startup.sh"

