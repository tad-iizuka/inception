#!/bin/bash

# Quit script when error happen
set -e

# Detect PHP version
PHP_VER=$(ls /etc/php | head -n 1)
echo "Detected PHP version: $PHP_VER"

# Check whether alredy installed
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "WordPress not found. Downloading..."
    
    # Download wordpress
    if [ ! -f /var/www/html/index.php ]; then
        curl -o wordpress.tar.gz -fSL "https://wordpress.org/latest.tar.gz"
        tar -xzf wordpress.tar.gz --strip-components=1 -C /var/www/html
        rm wordpress.tar.gz
        chown -R www-data:www-data /var/www/html
    fi

    if [ ! -f /var/www/html/wp-config.php ]; then
        echo "Creating wp-config.php..."
        
        if [ -f "$WORDPRESS_DB_PASSWORD_FILE" ]; then
            WORDPRESS_DB_PASSWORD=$(cat "$WORDPRESS_DB_PASSWORD_FILE")
            echo "mariadb password loaded from secret file"
        fi

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
                echo "Testing direct connection..."
                mysql -h"${WORDPRESS_DB_HOST%:*}" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -e "SELECT 1" 2>&1 || true
                exit 1
            fi
            echo "Database is unavailable - sleeping (attempt $COUNT/$MAX_TRIES)"
            sleep 3
        done
        
        echo "Database is ready!"
        
        # Create wp-config.php
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
            define('WP_REDIS_HOST', 'redis');
            define('WP_REDIS_PORT', 6379);
            define('WP_CACHE_KEY_SALT', 'tiizuka.42.fr');
            define('WP_REDIS_CLIENT', 'phpredis');

            if ( ! defined( 'ABSPATH' ) ) {
                define( 'ABSPATH', __DIR__ . '/' );
            }

            require_once ABSPATH . 'wp-settings.php';
WPCONFIG
        
        # Extract environments
        sed -i "s/\${WORDPRESS_DB_NAME}/${WORDPRESS_DB_NAME}/g" /var/www/html/wp-config.php
        sed -i "s/\${WORDPRESS_DB_USER}/${WORDPRESS_DB_USER}/g" /var/www/html/wp-config.php
        sed -i "s/\${WORDPRESS_DB_PASSWORD}/${WORDPRESS_DB_PASSWORD}/g" /var/www/html/wp-config.php
        sed -i "s/\${WORDPRESS_DB_HOST}/${WORDPRESS_DB_HOST}/g" /var/www/html/wp-config.php
        
        chown www-data:www-data /var/www/html/wp-config.php
        chmod 640 /var/www/html/wp-config.php
        echo "wp-config.php created successfully!"
    fi
fi

# Change permission
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \; 2>/dev/null || true
find /var/www/html -type f -exec chmod 644 {} \; 2>/dev/null || true

# Initialize WordPress
if [ -f /var/www/html/wp-config.php ]; then
    if ! wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
        echo "Installing WordPress..."

        WORDPRESS_SITE_URL="${WORDPRESS_SITE_URL:-http://localhost:8080}"
        WORDPRESS_SITE_TITLE="${WORDPRESS_SITE_TITLE:-My WordPress Site}"
        WORDPRESS_ADMIN_EMAIL="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}"

        if [ -f "$WP_ADMIN_PASSWORD_FILE" ]; then
            WORDPRESS_ADMIN_PASSWORD=$(cat "$WP_ADMIN_PASSWORD_FILE")
            echo "Admin password loaded from secret file"
        else
            WORDPRESS_ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD:-password42}"
            echo "Admin password loaded from environment variable or default"
        fi

        if [ -f "$WP_GUEST_PASSWORD_FILE" ]; then
            WORDPRESS_GUEST_PASSWORD=$(cat "$WP_GUEST_PASSWORD_FILE")
            echo "Guest password loaded from secret file"
        else
            WORDPRESS_GUEST_PASSWORD="${WORDPRESS_GUEST_PASSWORD:-password42}"
            echo "Guest password loaded from environment variable or default"
        fi

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

        echo "Installing Redis Cache plugin..."
        wp plugin install redis-cache --activate --allow-root
        wp plugin update --all --allow-root
        wp redis enable --allow-root
        echo "Redis Cache plugin installed and enabled!"

        wp language core install en_US --activate --path=/var/www/html --allow-root
        echo "Language set to English (en_US)"

        wp user create guest guest@example.com \
            --role=author \
            --user_pass="$WORDPRESS_GUEST_PASSWORD" \
            --path=/var/www/html \
            --porcelain \
            --allow-root
        
        echo "Author user 'guest' created successfully!"
        
        # WP settings
        WORDPRESS_TIMEZONE="${WORDPRESS_TIMEZONE:-Asia/Tokyo}"
        wp option update timezone_string "$WORDPRESS_TIMEZONE" --path=/var/www/html --allow-root
        echo "Timezone set to: $WORDPRESS_TIMEZONE"
        
        wp rewrite structure '/%postname%/' --path=/var/www/html --allow-root
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
if command -v php-fpm${PHP_VER} >/dev/null 2>&1; then
    echo "Found PHP-FPM ${PHP_VER}"
    exec php-fpm${PHP_VER} -F -R
elif command -v php-fpm >/dev/null 2>&1; then
    echo "Found generic PHP-FPM"
    exec php-fpm -F -R
else
    echo "PHP-FPM not found!"
    find /usr -name "php-fpm*" 2>/dev/null
    exit 1
fi
