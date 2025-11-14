# Penultimate stable version of Debian
FROM debian:bookworm

# Install packages
RUN apt-get update && apt-get install -y redis \
    && rm -rf /var/lib/apt/lists/*

# Copy script
COPY ./tools/redis.sh /tmp/redis.sh
RUN chmod +x /tmp/redis.sh

# Expose port
EXPOSE 6379

CMD ["sh", "/tmp/redis.sh"]
