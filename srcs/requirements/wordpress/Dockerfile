# Penultimate stable version of Debian
FROM debian:bookworm

# Environment settings
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update && apt-get install -y \
	mariadb-client \
    php-fpm \
    php-mysqli \
    php-gd \
    php-zip \
    php-intl \
    php-mbstring \
    php-xml \
    php-curl \
    php-imagick \
    php-bcmath \
    php-exif \
    php-soap \
    php-xmlrpc \
    php-opcache \
    vim \
    wget \
    curl \
    zip \
    unzip \
    git \
    locales \
    ca-certificates \
    && sed -i -e 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# PHP-FPM settings
RUN PHP_VER=$(ls /etc/php | head -n 1) && \
    sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 9000|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
    sed -i 's|;listen.owner = www-data|listen.owner = www-data|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
    sed -i 's|;listen.group = www-data|listen.group = www-data|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
    sed -i 's|;listen.mode = 0660|listen.mode = 0660|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf

# Copy php settings
COPY php.ini /etc/php/${PHP_VER}/fpm/conf.d/99-custom.ini
COPY ./conf/www.conf /etc/php/${PHP_VER}/fpm/pool.d/zz-custom.conf

# Instal WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create WordPress directory
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html

# Copy script
COPY ./tools/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html

# Expose port
EXPOSE 9000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["sh", "-c", "php-fpm${PHP_VER} -F -R"]
