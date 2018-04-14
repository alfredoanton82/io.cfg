#/bin/bash

# Define configuration path
CONFIG_PATH=/root/@server@.cfg/config

cd /var/www/

echo "Installing PhpSysInfo"
echo ""

prevVer=$(ls -d phpsysinfo-*)
echo "Remove previous version: $prevVer"
rm -rf $prevVer

echo "Downloading PhpSysInfo..."
wget http://sourceforge.net/projects/phpsysinfo/files/latest/download?source=files --no-check-certificate -O phpsysinfo-latest.tar.gz

# Getting filename
dlfile=$(ls phpsysinfo*.tar.gz)

echo ""
echo "Uncompressing PhpSysInfo"
pv $dlfile | tar xfz -
rm -f $dlfile

# Getting folder
currVer=$(ls -d phpsysinfo-*)

# Copy configuration file
echo ""
echo "Setting configuration file"
cp -vf $CONFIG_PATH/var/www/phpsysinfo/phpsysinfo.ini ${currVer}/phpsysinfo.ini

# Link folder to nginx default configuration
ln -sf ../$currVer /var/www/html/phpsysinfo

# Update rights
chown -R www-data:www-data $currVer
chmod -R o-w $currVer

echo ""
echo "Restarting nginx"
systemctl restart nginx
systemctl status  nginx
