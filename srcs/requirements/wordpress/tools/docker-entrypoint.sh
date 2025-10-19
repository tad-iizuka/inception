#!/bin/bash
set -e

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
        until mysql -h"${WORDPRESS_DB_HOST%:*}" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
            echo "Database is unavailable - sleeping"
            sleep 3
        done
        echo "Database is ready!"
        
        # wp-config.phpの生成
        cat > /var/www/html/wp-config.php <<EOF
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

\$table_prefix = 'wp_';

define('WP_DEBUG', false);

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF
        
        chown www-data:www-data /var/www/html/wp-config.php
        chmod 640 /var/www/html/wp-config.php
        
        echo "wp-config.php created successfully!"
    fi
fi

# パーミッション修正
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

echo "Starting PHP-FPM..."
exec "$@"
