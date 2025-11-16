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
    echo "mariadb user password loaded from secret file"
fi

if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
    echo "Error: MARIADB_ROOT_PASSWORD is not set"
    exit 1
fi

# Check whether password is set
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "MariaDB not initialized. Initializing..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    INIT_REQUIRED=true
else
    INIT_REQUIRED=false
fi

# Temporary mysqld activate, TCP is not valid, via socket.
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
MYSQL_PID=$!

# Waiting
for i in {60..0}; do
    if mysqladmin ping --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

if [ "$i" = 0 ]; then
    echo "MariaDB failed to start"
    exit 1
fi

# Delete root@localhost, Password is mandatory.
mysql <<EOSQL
-- delete root@localhost
DROP USER IF EXISTS 'root'@'localhost';

-- create root@% for TCP connection
CREATE USER 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- test database delete
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
DELETE FROM mysql.user WHERE User='';

FLUSH PRIVILEGES;
EOSQL

# Create database and users
if [ ! -z "$MARIADB_DATABASE" ] && [ ! -z "$MARIADB_USER" ]; then
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS '${MARIADB_USER}'@'%';
DROP USER IF EXISTS '${MARIADB_USER}'@'localhost';
CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
CREATE USER '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOSQL
fi

# Temporary mysqld stop
mysqladmin -u root -p"${MARIADB_ROOT_PASSWORD}" shutdown

# mysqld activate (TCP enable)
echo "Starting MariaDB server..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --console
