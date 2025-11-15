# Penultimate stable version of Debian
FROM debian:bookworm

# Install packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl && \
    apt-get install -y tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=tiizuka.42.fr"

# Expose port
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
