#!/bin/bash

APT_GET="$(which apt-get) -y"
APT_SRC_LIST=/etc/apt/sources.list

# Setting locale
LG==en_US.UTF-8
if [ -z $LANG ] && [ $LANG != $LG ]; then
  export LANGUAGE=$LG
  export LANG=$LG
  export LC_ALL=$LG
  locale-gen $LG
  update-locale $LG
fi

# Check sources list
grep stretch $APT_SRC_LIST &>/dev/null
if [ $? != 0 ]; then
  echo "Adding source 'stretch' to sources list"
  echo "deb http://mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi" >> $APT_SRC_LIST
fi

# Update and upgrade packages
$APT_GET update && $APT_GET upgrade

# Install Tools
$APT_GET install pv rsync git

# Install NETWORK packages
$APT_GET install ntp dnsmasq dnsutils nmap arp-scan

# Install MAIL packages
$APT_GET install ssmtp mailutils mutt

# Install RPi packages
$APT_GET install rpi-update

# Install PHP packages
$APT_GET install  php7.0     php7.0-curl    php7.0-gd       php7.0-fpm \
                  php7.0-cli php7.0-opcache php7.0-mbstring php7.0-xml \
                  php7.0-zip php7.0-pgsql

# Install NGINX packages
$APT_GET install nginx

# Install Postgresql packages
$APT_GET install postgresql libpq5 libpq-dev
