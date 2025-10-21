# Penultimate stable version of Debian
FROM debian:bookworm

# Install packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Generate self-signed SSL certificate (valid for 1 year)
RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=tiizuka.42.fr"

# Copy nginx configuration
COPY ./conf/default.conf /etc/nginx/conf.d/default.conf

# Remove the default site configuration if it exists
RUN rm -f /etc/nginx/sites-enabled/default

# Expose HTTPS port
EXPOSE 443

# Start Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
