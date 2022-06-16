FROM mariadb:10.7.4

RUN apt update
# RUN apt-get -y install locales-all

RUN apt install -y vim
RUN apt install -y less

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
