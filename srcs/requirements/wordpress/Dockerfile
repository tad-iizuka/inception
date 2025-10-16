FROM wordpress:latest

# 必要なパッケージのインストール
RUN apt-get update && \
    apt-get install -y \
    vim \
    wget \
    curl \
    zip \
    unzip \
    git \
    locales && \
    sed -i -e 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=ja_JP.UTF-8
ENV LANGUAGE=ja_JP:ja
ENV LC_ALL=ja_JP.UTF-8

COPY php.ini /usr/local/etc/php/conf.d/custom.ini

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html

EXPOSE 9000

# カスタムエントリーポイントを削除
# デフォルトのWordPressエントリーポイントを使用
