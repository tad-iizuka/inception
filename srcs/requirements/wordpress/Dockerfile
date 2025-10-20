# Penultimate stable version of Debian
FROM debian:bookworm

# 環境変数設定
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=ja_JP.UTF-8
ENV LANGUAGE=ja_JP:ja
ENV LC_ALL=ja_JP.UTF-8

# 必要なパッケージとPHP-FPMのインストール
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

# PHP-FPM設定を変更（UnixソケットからTCPに変更）
# RUN sed -i 's|listen = /run/php/php-fpm.sock|listen = 9000|g' /etc/php/8.2/fpm/pool.d/www.conf && \
#     sed -i 's|;listen.owner = www-data|listen.owner = www-data|g' /etc/php/8.2/fpm/pool.d/www.conf && \
#     sed -i 's|;listen.group = www-data|listen.group = www-data|g' /etc/php/8.2/fpm/pool.d/www.conf && \
#     sed -i 's|;listen.mode = 0660|listen.mode = 0660|g' /etc/php/8.2/fpm/pool.d/www.conf
# RUN PHP_VER=$(ls /etc/php | head -n 1) && \
#     sed -i 's|listen = /run/php/php-fpm.sock|listen = 9000|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
#     sed -i 's|;listen.owner = www-data|listen.owner = www-data|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
#     sed -i 's|;listen.group = www-data|listen.group = www-data|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
#     sed -i 's|;listen.mode = 0660|listen.mode = 0660|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf
RUN PHP_VER=$(ls /etc/php | head -n 1) && \
    sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 9000|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
    sed -i 's|;listen.owner = www-data|listen.owner = www-data|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
    sed -i 's|;listen.group = www-data|listen.group = www-data|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf && \
    sed -i 's|;listen.mode = 0660|listen.mode = 0660|g' /etc/php/$PHP_VER/fpm/pool.d/www.conf

# カスタムPHP設定
COPY php.ini /etc/php/8.3/fpm/conf.d/99-custom.ini
COPY ./conf/www.conf /etc/php/8.3/fpm/pool.d/zz-custom.conf

# WP-CLIのインストール
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Composerのインストール
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# WordPressディレクトリの作成
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html

# エントリーポイントスクリプトのコピー
COPY ./tools/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm8.4", "-F", "-R"]
