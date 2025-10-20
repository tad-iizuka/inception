FROM debian:latest

# 環境変数設定
ENV DEBIAN_FRONTEND=noninteractive

# MariaDBのインストール
RUN apt-get update && apt-get install -y \
    mariadb-server \
    mariadb-client \
    locales \
    && sed -i -e 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# MariaDBのデータディレクトリとログディレクトリの作成
RUN mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && chmod 755 /var/run/mysqld

# カスタム設定ファイルをコピー
COPY ./conf/my.cnf /etc/mysql/conf.d/custom.cnf

# エントリーポイントスクリプトのコピー
COPY ./tools/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 初期化スクリプト用のディレクトリ
RUN mkdir -p /docker-entrypoint-initdb.d

EXPOSE 3306

VOLUME /var/lib/mysql

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]
