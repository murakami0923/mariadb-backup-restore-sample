FROM ubuntu:22.04

RUN apt update
RUN apt upgrade -y
RUN apt install -y cron
RUN apt install -y vim
RUN apt install -y less
RUN apt install -y mysql-client

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

