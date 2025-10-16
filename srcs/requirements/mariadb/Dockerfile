FROM mariadb:latest

# 日本語ロケールの設定
RUN apt-get update && \
    apt-get install -y locales && \
    sed -i -e 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=ja_JP.UTF-8
ENV LANGUAGE=ja_JP:ja
ENV LC_ALL=ja_JP.UTF-8

# カスタム設定ファイルをコピー
COPY my.cnf /etc/mysql/conf.d/custom.cnf

# 初期化スクリプト用のディレクトリ（オプション）
# COPY init-scripts/ /docker-entrypoint-initdb.d/

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD mysqladmin ping -h localhost -u root -p$(cat /run/secrets/db_root_password) || exit 1

EXPOSE 3306
