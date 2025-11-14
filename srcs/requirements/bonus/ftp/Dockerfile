# Penultimate stable version of Debian
FROM debian:bookworm

# Install packages
RUN apt-get update && apt-get install -y vsftpd

# Copy script
COPY ./conf/vsftpd.conf /tmp/vsftpd.conf
COPY ./tools/ftp.sh /tmp/ftp.sh
RUN chmod +x /tmp/ftp.sh

CMD ["sh", "/tmp/ftp.sh"]
