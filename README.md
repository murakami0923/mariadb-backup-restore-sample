# MySQL、MariaDBでバックアップ、バイナリログから復旧する手順、サンプル (LinuxにMySQLをMariaDBをインストール)

- [MySQL、MariaDBでバックアップ、バイナリログから復旧する手順、サンプル (LinuxにMySQLをMariaDBをインストール)](#mysqlmariadbでバックアップバイナリログから復旧する手順サンプル-linuxにmysqlをmariadbをインストール)
- [背景](#背景)
- [本書およびサンプルの概要](#本書およびサンプルの概要)
- [参考サイト](#参考サイト)
- [注意、制約](#注意制約)
- [前提](#前提)
  - [Linux、Docker、Docker Compose](#linuxdockerdocker-compose)
  - [MariaDBのバージョン](#mariadbのバージョン)
- [サンプルの環境の起動](#サンプルの環境の起動)
- [解説](#解説)
  - [バイナリログ有効化](#バイナリログ有効化)
  - [バイナリログのファイル確認](#バイナリログのファイル確認)
  - [完全バックアップ](#完全バックアップ)
  - [DBを更新するアプリケーションを停止](#dbを更新するアプリケーションを停止)
  - [DBの更新が止まることを確認](#dbの更新が止まることを確認)
  - [データを削除（ミスの操作を再現）](#データを削除ミスの操作を再現)
  - [バイナリログから増分のクエリを抽出](#バイナリログから増分のクエリを抽出)
  - [データベースの復旧](#データベースの復旧)
- [おわりに](#おわりに)

# 背景

DBを使ったWebサイトやシステムなどで、本番の更新・リリース作業を行うときに、

- 作業ミスでテーブルのデータを削除（delete、truncate）してしまった
- 作業ミスでテーブルを削除（drop）してしまった
- そもそも作業手順に問題があって、データやテーブルを削除してしまった

というような話を聞いたことがあります。

作業手順のレビューをしたり、実施時にダブルチェックしたとしても、ミスを完全になくすのは不可能です。
それに、Ansibleのように自動化する方法を使っても、定義を作るのは人なので、誤りを完全に防ぐことも不可能です。

そこで、上記のようなトラブルでDBを破壊したとしても、DBのバックアップとバイナリログで、「○○○○年○○月○○日 ○時○分の時点に戻したい」という願いを実現する方法を探ることにしました。

# 本書およびサンプルの概要

`mysqldump`コマンドで完全バックアップをし、さらに、バイナリログを保存して増分バックアップとして使用し、DBを復旧する手順をまとめます。
完全バックアップの作成、および、バイナリログからのSQL作成の際には、データベースを指定することとします。

サンプルは、[https://github.com/murakami0923/mariadb-backup-restore-sample](https://github.com/murakami0923/mariadb-backup-restore-sample)に置いてあります。

MariaDBと、そのDBを更新するアプリケーションを、それぞれDockerコンテナとして作成し、そのうえで、バックアップ・復旧を試せるようにします。

各コンテナの概要：

- MariaDBのコンテナ
  - `my.cnf`でバイナリログを有効化します
- アプリケーションのコンテナ
  - 起動時に、MariaDBコンテナにテーブルがなければテーブルを作成します
  - テーブルにレコードを登録（insert）するbashスクリプトをcronで定期的に呼び出します
  - bashスクリプトでは、一定間隔（デフォルト：5秒間隔）でSQLを生成し、MariaDBコンテナにmysqlコマンドで接続して実行します。

# 参考サイト

[MySQL 5.6 リファレンスマニュアル - 7.3.1 バックアップポリシーの確立](https://dev.mysql.com/doc/refman/5.6/ja/backup-policy.html)

# 注意、制約

- **今回紹介するのは、非常時の手順です。DBへの変更(スキーマ、データなど)を伴う作業の際には、かならず変更前にバックアップするようにしましょう。**
- 今回の手順では、**DBサーバ（本サンプルではコンテナ）でrootユーザーで接続する必要があります。**
- テーブルはMySQLのInnoDBで作成したものとします。
- DBの復旧の際は、DBを更新するサービスを停止して行うことを前提とします。
  - Webサーバやアプリケーションサーバを停止すると、アクセスしてもエラーになります。
  - あらかじめSorryページ等を用意しておくことが望ましいです。
- ファイル（画像、データファイル、レポートなど）のバックアップ、復旧は扱いません。
- 本手順では、Linux等のローカル環境に自前でMySQLあるいはMariaDBをインストールして使用するケースを想定します。
  - サンプルでは、`mariadb`イメージのコンテナを使用します。
  - AWS RDS, Aurora等のマネージドクラウドサービスでは、別の復旧手順があるので、公式情報等をご参照ください。
    - 余裕があったらAuroraでの復旧手順をまとめてみたい（約束はできません）

# 前提
## Linux、Docker、Docker Compose

Ubuntu 20.04に、Docker、Docker Composeをインストールし、実行することを想定しています。

インストール手順は、手前味噌ですが、[Ubuntu 20.04にDocker、Docker Composeをインストールする手順 - Qiita](https://qiita.com/murakami77/items/98ef607dc4ff0ae9a497)に記載していますので、よろしければご参照ください。

## MariaDBのバージョン

DBは`mariadb:10.7.4`のイメージをベースに、ロケール等を変更した、独自のイメージを定義・ビルドして使います。

DBのコンテナでのバージョン確認の例：

```bash
mysql --version
```

↓実行結果

```txt
mysql  Ver 15.1 Distrib 10.7.4-MariaDB, for debian-linux-gnu (x86_64) using readline 5.2
```

# サンプルの環境の起動

まず、GitHubからリポジトリをcloneします。

```bash
git clone https://github.com/murakami0923/mariadb-backup-restore-sample.git
```

次に、リポジトリのディレクトリへ移動し、Docker Composeでコンテナを起動します。<br>※初回の起動時は、Dockerfileをビルドしてイメージを作成するので、時間がかかります。

```bash
cd mariadb-backup-restore-sample/
docker-compose up -d
```

使い終わったらコンテナを終了します。

```bash
docker-compose down
```

# 解説
## バイナリログ有効化

DBの設定ファイル`my.cnf`に、バイナリログを有効化するための設定を追記しています。

実際にDBを運用する際にも、**最初からバイナリログを有効化**しておきましょう。

```cnf
#バイナリログ有効化
log-bin=mysql-bin
```

設定ファイルについては、本サンプル（`mariadb:10.7.4`ベースのイメージのコンテナ）では`/etc/alternatives/my.cnf`ですが、環境によっては`/etc/my.cnf`に直接書かれている可能性もあり、設定する環境のファイルを調べます。

なお、本サンプルでは、更新する前の`my.cnf`を予め取得し、さらにバイナリログ有効化の設定を追記した、`my.cnf`の完全版のファイルを、`db/my.cnf`に置いてあります。


## バイナリログのファイル確認

サンプルでは、まず、MariaDBコンテナに入ります。

```bash
docker exec -ti mariadb-backup-restore-sample-db-1 /bin/bash
```

次に、`mysql`コマンドで`root`ユーザーで接続し、下記SQLを実行します。

```bash
export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}
mysql -u root ${MYSQL_DATABASE}
```

```sql
SHOW MASTER STATUS;
```

実行すると、

```txt
MariaDB [(none)]> SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000002 |   109561 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.004 sec)
```

のように、バイナリログの状況が表示されます。

データが更新されるごとに、上記を実行すると`Position`の値が大きくなっていきます。


## 完全バックアップ

定期的にDBの完全バックアップも取るように設定しておきます。<br>※ DBのサイズ、更新頻度、サービスの夜間・週末などの休止可能時間などをみて、スケジュールを決めましょう。

cronなどで、下記のようなコマンドを設定します。

```bash
mysqldump --single-transaction --flush-logs --master-data=2 {データベース名} > {バックアップファイル名}
```

オプション：

| オプション | 値 | 解説 |
| :- | :- | :- |
| --single-transaction | (なし) | ダンプ処理をトランザクションで囲みます。データの整合性を保つのに有効です。ただし、MyISAMテーブルが含まれるDBでは意味が無いので、代わりに`--lock-tables`か`--lock-all-tables`を使いましょう。 |
| --flush-logs | (なし) | バイナリログをフラッシュします。（現在のバイナリログファイルを閉じ、新しいログファイルを次のシーケンス番号で開きます。）<br>これにより、新しいログファイルが、この完全バックアップより後の増分となります。 |
| --master-data | 2 | mysqldumpの出力に、バイナリログ情報が書き込まれます。 |

サンプルでは、まず、MariaDBコンテナに入ります。

```bash
docker exec -ti mariadb-backup-restore-sample-db-1 /bin/bash
```

次にbashで下記を実行します。

```bash
cd /var/lib/mysql/
dump_file=app-full-`date '+%Y%m%d-%H%M%S'`.sql
export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}
mysqldump --single-transaction --flush-logs --master-data=2 ${MYSQL_DATABASE} > ${dump_file}
```

その後で、mysqlインタープリタで

```sql
SHOW MASTER STATUS;
```

実行します。

```txt
MariaDB [test]> SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000003 |      699 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.000 sec)
```

のように、`File`の項目の連番が増えて、`Position`の値が小さくなることを確認します。


また、バックアップファイルに保存された、バイナリログの情報を確認します。

```bash
grep "CHANGE MASTER TO MASTER_LOG_FILE=" ${dump_file}
```

を実行すると、

```txt
-- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000003', MASTER_LOG_POS=385;
```

のように、バイナリログ情報が確認できます。

## DBを更新するアプリケーションを停止

リリースの際、まずDBへの更新を止め、アプリケーション等を更新することが多いと思います。

サンプルでは、まず、アプリケーションコンテナに入ります。

```bash
docker exec -ti mariadb-backup-restore-sample-app-1 /bin/bash
```

次に、cronの設定を変更します。

```bash
crontab -e
```

でcronの設定のエディタが開くので、DB更新のシェルスクリプト呼び出しをコメントアウトします。

```txt
# * * * * * export TZ=Asia/Tokyo; /root/update-db.sh >> /root/cron-update-db.log 2>&1
```

これで保存します。

## DBの更新が止まることを確認

その後、mysqlインタープリタで

```sql
SHOW MASTER STATUS; SELECT COUNT(*) FROM `test`.`test_data`;
```

を実行します。

```txt
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000003 |   161153 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.000 sec)

+----------+
| COUNT(*) |
+----------+
|     5532 |
+----------+
1 row in set (0.008 sec)
```

バイナリログの状況と、テーブルのレコード数が表示されます。

何度か実行し、更新が止まるまで待ちます。
※1分ほどかかることがあります。

更新が止まったら、上記を控えておきましょう。
※あとで使います。

## データを削除（ミスの操作を再現）

ここで、リリース時にミスをしたとしましょう。
たとえば、テーブルのデータを誤って消してしまったとします

サンプルでは、下記SQLを実行します。（rootでmysqlにログイン）

```sql
TRUNCATE TABLE `test_data`;
```

## バイナリログから増分のクエリを抽出

YYYY年MM月DD日　hh時mm分ss秒の時点まで戻したいとします。

MariaDBのコンテナのbashで、

```bash
mysqlbinlog --stop-datetime="YYYY-MM-DD hh:mm:ss" --database=${MYSQL_DATABASE} ｛バイナリログファイル｝ > app-incremental-backup-YYYYMMDD-hhmmss.sql
```

のように実行すると、指定した時刻までの増分のクエリが抽出・保存されます。

オプション：

| オプション | 値 | 解説 |
| :- | :- | :- |
| --stop-datetime | 復旧する日時 | "YYYY-MM-DD hh:mm:ss" の書式で指定します。 |
| --databases | DB名 | 復旧するDB名を指定します。 |

具体的：

```bash
mysqlbinlog --stop-datetime="2022-06-15 14:15:00" --database=${MYSQL_DATABASE} mysql-bin.000003 > app-incremental-backup-20220615-141500.sql
```

※可能であれば、ミスの操作をする前と、した後のログを抽出するといいでしょう。
　（diffで、ミスの操作を確認することができます）

## データベースの復旧

DBを復旧するには、

- DBを一旦削除
- 完全バックアップからDBを作成
- バイナリログから抽出した更新分のクエリを適用

の手順で行います。

MariaDBのコンテナのbashで、

```bash
export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}
mysql -u root -e "DROP DATABASE ${MYSQL_DATABASE};"
mysql -u root -e "CREATE DATABASE ${MYSQL_DATABASE};"
mysql -u root -e "FLUSH LOGS;"
```

を実行し、一旦DBを削除します。

次に、完全バックアップのファイルでDBを作成します。

```bash
cd /var/lib/mysql/
mysql -u root ${MYSQL_DATABASE} < {完全バックアップファイル名}
```

次に、バイナリログから抽出した増分のクエリで、増分を適用します。

```bash
mysql -u root ${MYSQL_DATABASE} < {増分のクエリファイル名}
```

実行できたら、mysqlインタープリタで

```sql
SHOW MASTER STATUS; SELECT COUNT(*) FROM `test`.`test_data`;
```

を実行します。

```txt
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000004 |   663283 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.001 sec)

+----------+
| COUNT(*) |
+----------+
|     5532 |
+----------+
1 row in set (0.009 sec)
```

# おわりに

- 今回紹介するのは、非常時の手順です。DBへの変更(スキーマ、データなど)を伴う作業の際には、かならず変更前にバックアップするようにしましょう。
  - リリース手順を作成する人が初めての場合など、慣れないうちは、手順をレビューしましょう。
- 万一、作業前にバックアップを取らずに作業し、ミス等でDBが壊れても、復旧できるように、以下の点に気を付けましょう。
  - MySQLやMariaDBでDBサーバを構築する際は、バイナリログを有効化しておきましょう。
    - ストレージも余裕をもって確保するようにしましょう。
  - 定期的にDBの完全バックアップも取るようにしましょう。
    - DBのサイズ、更新頻度、サービスの夜間・週末などの休止可能時間などをみて、スケジュールを決めましょう。
  - 上記の手順では、DBサーバ（本サンプルではコンテナ）でrootユーザーで接続する必要があります。
    - いざという時に一時的にrootユーザーで作業できるようにするか、`sudo`等で設定しておくなど、備えておくといいと思います。