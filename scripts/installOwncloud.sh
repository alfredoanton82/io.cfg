#/bin/bash

echo "Installing Owncloud Server"
echo ""
echo "When prompted to overwrite files, choose NOT to overwrite them."
echo "Overwriting the files may cause your system to **bleep**. So dont."
read -p "Do you understand and wish to continue? [y/N] " -n 1
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\nUSER ABORT\n"
    exit 1;
fi

# Getting hostname
hostname=$(hostname |  tr '[A-Z]' '[a-z]')

# Creating owncloud user on Postgresql DB
# Encrypted using md5: echo -n '<password><user>' | md5sum and put md5 before
export PGPASSWORD='md5ba7ebe15e3fa1fd83c396e451ebc3f08'

# Create pqsql script
owncloudpsql=owncloud.sql
rm -f $owncloudpsql
echo "DROP DATABASE owncloud ;"                               >> $owncloudpsql
echo "DROP ROLE owncloud ;"                                   >> $owncloudpsql
echo "CREATE ROLE owncloud ;"                                 >> $owncloudpsql
echo "ALTER ROLE owncloud ENCRYPTED PASSWORD '$PGPASSWORD' ;" >> $owncloudpsql
echo "ALTER ROLE owncloud LOGIN ;"                            >> $owncloudpsql
echo "CREATE DATABASE owncloud ;"                             >> $owncloudpsql
echo "ALTER DATABASE owncloud OWNER TO owncloud ;"            >> $owncloudpsql
echo "\list"                                                  >> $owncloudpsql
echo "\q"                                                     >> $owncloudpsql

echo ""
echo -n "Configuring database owncloud..."
psql -U postgres -a -w -f $owncloudpsql 
if [ $? -eq 0 ]; then
  echo OK
  rm -f $owncloudpsql
else
  echo NOK
  exit 1
fi

echo
echo "Downloading OwnCloud"
cd /var/www/
rm -f setup-owncloud.php
wget https://download.owncloud.com/download/community/setup-owncloud.php --no-check-certificate
chmod 755 setup-owncloud.php
chgrp www-data /var/www
chmod g+w /var/www

read -p  "Use installation wizard (http://${hostname}/setup-owncloud.php) before continue [Enter]..."

echo "Restarting Apache..."
/etc/init.d/nginx restart
chmod g-w /var/www
chmod o-w -R /var/www/owncloud

dataFolder="/DataVolume/owncloud_data"
owncloudData="/var/www/owncloud/data"
echo "Re-linking data folders $dataFolder..."

/etc/init.d/nginx stop
chgrp www-data $dataFolder
chmod 770 $dataFolder
for data in $(ls -1 $dataFolder); do 
  echo " - $data"
  ln -s ${dataFolder}/$data ${owncloudData}/$data
done
/etc/init.d/nginx start
