# Penultimate stable version of Debian
FROM debian:bookworm

# Environment
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update && apt-get install -y \
    mariadb-server \
    mariadb-client \
    locales \
    && sed -i -e 's/# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create data and log directories
RUN mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && chmod 755 /var/run/mysqld

# Copy custome settings
COPY ./conf/my.cnf /etc/mysql/conf.d/custom.cnf

# Copy script
COPY ./tools/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create directory
RUN mkdir -p /docker-entrypoint-initdb.d

# Port expose
EXPOSE 3306

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]
