#/bin/bash

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
cp -vf /root/config/phpsysinfo.ini ${currVer}/phpsysinfo.ini

ln -sf $currVer phpsysinfo

chown -R www-data:www-data $currVer phpsysinfo
chmod -R o-w $currVer phpsysinfo


echo ""
echo "Restarting apache"
/etc/init.d/nginx restart
