#!/bin/bash

# Quit script when error happen
set -e

# Read password
if [ -f "$MARIADB_ROOT_PASSWORD_FILE" ]; then
    MARIADB_ROOT_PASSWORD=$(cat "$MARIADB_ROOT_PASSWORD_FILE")
    echo "mariadb root password loaded from secret file"
fi

if [ -f "$MARIADB_PASSWORD_FILE" ]; then
    MARIADB_PASSWORD=$(cat "$MARIADB_PASSWORD_FILE")
    echo "mariadb password loaded from secret file"
fi

# Check whether password is set
if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
    echo "Error: MARIADB_ROOT_PASSWORD is not set"
    exit 1
fi

# Check whether database init is necessary
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
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Initialize database
if [ "$NEEDS_INIT" = true ] || [ "$NEEDS_USER_SETUP" = true ]; then
    echo "Starting temporary MariaDB instance..."
    mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
    MYSQL_PID=$!

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
    echo "Setting up database and users..."
    
    if [ "$NEEDS_INIT" = true ]; then
        mysql <<-EOSQL
			-- setting root password
			ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
			CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
			GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
			
			-- delete users
			DROP DATABASE IF EXISTS test;
			DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
			DELETE FROM mysql.user WHERE User='';
		EOSQL
    fi

    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
		-- create database
		CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
		
		-- create user
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

        touch /var/lib/mysql/.user_setup_complete
    else
        echo "Failed to create database and user"
        exit 1
    fi

    echo "Stopping temporary MariaDB instance..."
    if ! kill -s TERM "$MYSQL_PID" || ! wait "$MYSQL_PID"; then
        echo "MariaDB shutdown failed"
        exit 1
    fi
    
    echo "MariaDB initialization completed"
else
    echo "MariaDB fully initialized and configured"
fi

# Start mariadb
echo "Starting MariaDB server..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --console
