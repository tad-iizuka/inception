#!/bin/bash
set -e

# パスワードファイルから読み込み
if [ -f "$MARIADB_ROOT_PASSWORD_FILE" ]; then
    MARIADB_ROOT_PASSWORD=$(cat "$MARIADB_ROOT_PASSWORD_FILE")
fi

if [ -f "$MARIADB_PASSWORD_FILE" ]; then
    MARIADB_PASSWORD=$(cat "$MARIADB_PASSWORD_FILE")
fi

# パスワードが設定されているか確認
if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
    echo "Error: MARIADB_ROOT_PASSWORD is not set"
    exit 1
fi

# 初期化が必要かチェック
NEEDS_INIT=false
NEEDS_USER_SETUP=false

if [ ! -d "/var/lib/mysql/mysql" ]; then
    NEEDS_INIT=true
    echo "MariaDB not initialized. Full initialization required."
else
    echo "MariaDB database directory exists. Checking if user setup is needed..."
    NEEDS_USER_SETUP=true
fi

if [ "$NEEDS_INIT" = true ]; then
    echo "Initializing MariaDB database..."
    
    # データベースの初期化
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

if [ "$NEEDS_INIT" = true ] || [ "$NEEDS_USER_SETUP" = true ]; then
    # 一時的にMariaDBを起動
    echo "Starting temporary MariaDB instance..."
    mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
    MYSQL_PID=$!
    
    # MariaDBが起動するまで待機
    echo "Waiting for MariaDB to start..."
    for i in {60..0}; do
        if mysqladmin ping -h localhost --silent 2>/dev/null; then
            echo "MariaDB is up!"
            break
        fi
        sleep 1
    done
    
    if [ "$i" = 0 ]; then
        echo "MariaDB failed to start"
        exit 1
    fi
    
    echo "MariaDB started successfully"
    
    # セキュリティ設定とユーザー作成
    echo "Setting up database and users..."
    
    if [ "$NEEDS_INIT" = true ]; then
        # 完全な初期化
        mysql <<-EOSQL
			-- rootパスワードの設定
			ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
			CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
			GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
			
			-- 不要なユーザーの削除
			DROP DATABASE IF EXISTS test;
			DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
			DELETE FROM mysql.user WHERE User='';
		EOSQL
    fi
    
    # データベースとユーザーの設定（常に実行）
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
		-- データベースの作成
		CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
		
		-- ユーザーの作成（既存があれば削除）
		DROP USER IF EXISTS '${MARIADB_USER}'@'%';
		DROP USER IF EXISTS '${MARIADB_USER}'@'localhost';
		
		CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
		CREATE USER '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';
		
		GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
		GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'localhost';
		
		FLUSH PRIVILEGES;
	EOSQL
    
    if [ $? -eq 0 ]; then
        echo "Database and user created successfully"
        echo "Database: ${MARIADB_DATABASE}"
        echo "User: ${MARIADB_USER}@%"
        
        # マーカーファイルを作成
        touch /var/lib/mysql/.user_setup_complete
    else
        echo "Failed to create database and user"
        exit 1
    fi
    
    # 一時起動したMariaDBを停止
    echo "Stopping temporary MariaDB instance..."
    if ! kill -s TERM "$MYSQL_PID" || ! wait "$MYSQL_PID"; then
        echo "MariaDB shutdown failed"
        exit 1
    fi
    
    echo "MariaDB initialization completed"
else
    echo "MariaDB fully initialized and configured"
fi

# 通常起動
echo "Starting MariaDB server..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --console
