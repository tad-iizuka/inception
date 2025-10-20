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

# WordPress初期設定（wp-cliを使用）
if [ -f /var/www/html/wp-config.php ]; then
    # WordPressがインストール済みかチェック
    if ! wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
        echo "Installing WordPress..."
        
        # 環境変数のデフォルト値設定
        WORDPRESS_SITE_URL="${WORDPRESS_SITE_URL:-http://localhost:8080}"
        WORDPRESS_SITE_TITLE="${WORDPRESS_SITE_TITLE:-My WordPress Site}"
        WORDPRESS_ADMIN_EMAIL="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}"
        
        # 管理者パスワードをSecretファイルから読み込み
        if [ -f "$WORDPRESS_ADMIN_PASSWORD_FILE" ]; then
            WORDPRESS_ADMIN_PASSWORD=$(cat "$WORDPRESS_ADMIN_PASSWORD_FILE")
            echo "Admin password loaded from secret file"
        else
            WORDPRESS_ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD:-password42}"
            echo "Admin password loaded from environment variable or default"
        fi
        
        # 追加ユーザーのパスワードをSecretファイルから読み込み
        if [ -f "$WORDPRESS_GUEST_PASSWORD_FILE" ]; then
            WORDPRESS_GUEST_PASSWORD=$(cat "$WORDPRESS_GUEST_PASSWORD_FILE")
            echo "Guest password loaded from secret file"
        else
            WORDPRESS_GUEST_PASSWORD="${WORDPRESS_GUEST_PASSWORD:-password42}"
            echo "Guest password loaded from environment variable or default"
        fi
        
        # WordPress コアインストール
        wp core install \
            --path=/var/www/html \
            --url="$WORDPRESS_SITE_URL" \
            --title="$WORDPRESS_SITE_TITLE" \
            --admin_user=tiizuka \
            --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
            --admin_email="$WORDPRESS_ADMIN_EMAIL" \
            --skip-email \
            --allow-root
        
        echo "WordPress core installed successfully!"
        
        # 言語設定を英語に
        wp language core install en_US --activate --path=/var/www/html --allow-root
        echo "Language set to English (en_US)"
        
        # 追加ユーザー（Author）の作成
        wp user create guest guest@example.com \
            --role=author \
            --user_pass="$WORDPRESS_GUEST_PASSWORD" \
            --path=/var/www/html \
            --porcelain \
            --allow-root
        
        echo "Author user 'guest' created successfully!"
        
        # タイムゾーン設定
        WORDPRESS_TIMEZONE="${WORDPRESS_TIMEZONE:-Asia/Tokyo}"
        wp option update timezone_string "$WORDPRESS_TIMEZONE" --path=/var/www/html --allow-root
        echo "Timezone set to: $WORDPRESS_TIMEZONE"
        
        # パーマリンク設定を投稿名ベースに
        wp rewrite structure '/%postname%/' --path=/var/www/html --allow-root
        
        # デフォルトテーマの有効化（Twenty Twenty-Four等の最新テーマ）
        wp theme activate $(wp theme list --status=inactive --field=name --path=/var/www/html --allow-root | head -n 1) --path=/var/www/html 2>/dev/null || true
        
        echo "WordPress initial setup completed!"
        echo "=========================================="
        echo "Admin User: tiizuka"
        echo "Admin Password: (from secret or env)"
        echo "Author User: guest"
        echo "Author Password: (from secret or env)"
        echo "Site URL: $WORDPRESS_SITE_URL"
        echo "=========================================="
    else
        echo "WordPress is already installed. Skipping initial setup."
    fi
fi

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
