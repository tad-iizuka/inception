#!/bin/bash
set -e

# PHPバージョンを検出
PHP_VER=$(ls /etc/php | head -n 1)
echo "Detected PHP version: $PHP_VER"

# WordPressがまだインストールされていない場合
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "WordPress not found. Downloading..."
    
    # WordPressのダウンロード
    if [ ! -f /var/www/html/index.php ]; then
        curl -o wordpress.tar.gz -fSL "https://wordpress.org/latest.tar.gz"
        tar -xzf wordpress.tar.gz --strip-components=1 -C /var/www/html
        rm wordpress.tar.gz
        chown -R www-data:www-data /var/www/html
    fi
    
    # wp-config.phpの作成
    if [ ! -f /var/www/html/wp-config.php ]; then
        echo "Creating wp-config.php..."
        
        # パスワードファイルから読み込み
        if [ -f "$WORDPRESS_DB_PASSWORD_FILE" ]; then
            WORDPRESS_DB_PASSWORD=$(cat "$WORDPRESS_DB_PASSWORD_FILE")
        fi
        
        # データベース接続を待機
        echo "Waiting for database..."
        MAX_TRIES=30
        COUNT=0
        
        until mysql -h"${WORDPRESS_DB_HOST%:*}" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
            COUNT=$((COUNT + 1))
            if [ $COUNT -ge $MAX_TRIES ]; then
                echo "ERROR: Could not connect to database after $MAX_TRIES attempts"
                echo "Trying to connect to: ${WORDPRESS_DB_HOST%:*}"
                echo "Username: $WORDPRESS_DB_USER"
                echo "Password length: ${#WORDPRESS_DB_PASSWORD}"
                
                # デバッグ情報
                echo "Testing direct connection..."
                mysql -h"${WORDPRESS_DB_HOST%:*}" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -e "SELECT 1" 2>&1 || true
                exit 1
            fi
            echo "Database is unavailable - sleeping (attempt $COUNT/$MAX_TRIES)"
            sleep 3
        done
        
        echo "Database is ready!"
        
        # wp-config.phpの生成
        cat > /var/www/html/wp-config.php <<'WPCONFIG'
<?php
define('DB_NAME', '${WORDPRESS_DB_NAME}');
define('DB_USER', '${WORDPRESS_DB_USER}');
define('DB_PASSWORD', '${WORDPRESS_DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST}');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('AUTH_KEY',         '$(openssl rand -base64 48)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 48)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 48)');
define('NONCE_KEY',        '$(openssl rand -base64 48)');
define('AUTH_SALT',        '$(openssl rand -base64 48)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 48)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 48)');
define('NONCE_SALT',       '$(openssl rand -base64 48)');

$table_prefix = 'wp_';

define('WP_DEBUG', false);

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
WPCONFIG
        
        # 環境変数を展開
        sed -i "s/\${WORDPRESS_DB_NAME}/${WORDPRESS_DB_NAME}/g" /var/www/html/wp-config.php
        sed -i "s/\${WORDPRESS_DB_USER}/${WORDPRESS_DB_USER}/g" /var/www/html/wp-config.php
        sed -i "s/\${WORDPRESS_DB_PASSWORD}/${WORDPRESS_DB_PASSWORD}/g" /var/www/html/wp-config.php
        sed -i "s/\${WORDPRESS_DB_HOST}/${WORDPRESS_DB_HOST}/g" /var/www/html/wp-config.php
        
        chown www-data:www-data /var/www/html/wp-config.php
        chmod 640 /var/www/html/wp-config.php
        
        echo "wp-config.php created successfully!"
    fi
fi

# パーミッション修正
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \; 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} \; 2>/dev/null || true

echo "Starting PHP-FPM..."

# PHP-FPM実行ファイルを検索して起動
if [ -x "/usr/sbin/php-fpm8.4" ]; then
    echo "Found PHP-FPM 8.4"
    exec /usr/sbin/php-fpm8.4 -F -R
elif [ -x "/usr/sbin/php-fpm${PHP_VER}" ]; then
    echo "Found PHP-FPM ${PHP_VER}"
    exec /usr/sbin/php-fpm${PHP_VER} -F -R
elif [ -x "/usr/sbin/php-fpm" ]; then
    echo "Found generic PHP-FPM"
    exec /usr/sbin/php-fpm -F -R
else
    echo "ERROR: PHP-FPM executable not found!"
    echo "Searching for PHP-FPM:"
    find /usr -name "php-fpm*" 2>/dev/null
    ls -la /usr/sbin/php* 2>/dev/null || true
    exit 1
fi
