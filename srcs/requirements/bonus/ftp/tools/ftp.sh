#!/bin/sh

# Read password
if [ -f "$FTP_PASSWORD_FILE" ]; then
    FTP_PASSWORD=$(cat "$FTP_PASSWORD_FILE")
    echo "FTP password loaded from secret file"
fi

if [ ! -f "/etc/vsftpd.conf.bak" ]; then

    mkdir -p /var/www/html
    mkdir -p /var/run/vsftpd/empty

    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    mv /tmp/vsftpd.conf /etc/vsftpd.conf

    # Add the FTP_USER, change his password and declare him as the owner of wordpress folder and all subfolders
    adduser $FTP_USER --disabled-password
    echo "$FTP_USER:$FTP_PASSWORD" | /usr/sbin/chpasswd &> /dev/null
    chown -R $FTP_USER:$FTP_USER /var/www/html

	#chmod +x /etc/vsftpd/vsftpd.conf
    echo $FTP_USER | tee -a /etc/vsftpd.userlist &> /dev/null

fi

/usr/sbin/vsftpd /etc/vsftpd.conf
