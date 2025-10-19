#!/bin/bash
set -e

# パスワードファイルから読み込み
if [ -f "$MARIADB_ROOT_PASSWORD_FILE" ]; then
    MARIADB_ROOT_PASSWORD=$(cat "$MARIADB_ROOT_PASSWORD_FILE")
fi

if [ -f "$MARIADB_PASSWORD_FILE" ]; then
    MARIADB_PASSWORD=$(cat "$MARIADB_PASSWORD_FILE")
fi

# 初期化が必要かチェック
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB database..."
    
    # データベースの初期化
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    
    # 一時的にMariaDBを起動
    mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
    MYSQL_PID=$!
    
    # MariaDBが起動するまで待機
    for i in {30..0}; do
        if mysqladmin ping -h localhost --silent; then
            break
        fi
        echo "Waiting for MariaDB to start..."
        sleep 1
    done
    
    if [ "$i" = 0 ]; then
        echo "MariaDB failed to start"
        exit 1
    fi
    
    echo "MariaDB started successfully"
    
    # セキュリティ設定とユーザー作成
    mysql <<-EOSQL
        -- rootパスワードの設定
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
        CREATE USER 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
        
        -- 不要なユーザーの削除
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        DELETE FROM mysql.user WHERE User='';
        
        -- データベースとユーザーの作成
        CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
        
        FLUSH PRIVILEGES;
EOSQL
    
    echo "Database and user created successfully"
    
    # 初期化スクリプトの実行（存在する場合）
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)
                echo "Running $f"
                . "$f"
                ;;
            *.sql)
                echo "Running $f"
                mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" < "$f"
                ;;
            *.sql.gz)
                echo "Running $f"
                gunzip -c "$f" | mysql -uroot -p"${MARIADB_ROOT_PASSWORD}"
                ;;
            *)
                echo "Ignoring $f"
                ;;
        esac
    done
    
    # 一時起動したMariaDBを停止
    if ! kill -s TERM "$MYSQL_PID" || ! wait "$MYSQL_PID"; then
        echo "MariaDB shutdown failed"
        exit 1
    fi
    
    echo "MariaDB initialization completed"
else
    echo "MariaDB database already initialized"
fi

# 通常起動
echo "Starting MariaDB..."
# exec mysqld --user=mysql --datadir=/var/lib/mysql --console
# exec mysqld --defaults-file=/etc/mysql/my.cnf --defaults-extra-file=/etc/mysql/conf.d/custom.cnf --user=mysql --datadir=/var/lib/mysql --console
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --console