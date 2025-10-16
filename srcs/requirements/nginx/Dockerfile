FROM debian:latest

# OpenSSLとNginxをインストール
RUN apt-get update && apt-get install -y nginx openssl && apt-get clean

# SSLディレクトリ作成
RUN mkdir -p /etc/nginx/ssl

# 自己署名証明書を自動生成
RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=JP/ST=Tokyo/L=Tokyo/O=MyCompany/OU=Dev/CN=localhost"

# Nginx設定ファイルをコピー
COPY ./conf/default.conf /etc/nginx/conf.d/default.conf

# ポート解放
EXPOSE 443

# 起動コマンド
CMD ["nginx", "-g", "daemon off;"]
