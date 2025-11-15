# Penultimate stable version of Debian
FROM debian:bookworm

# Install packages
RUN apt-get update && apt-get install -y nginx && \
    apt-get install -y tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Expose port
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
