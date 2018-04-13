#!/bin/bash
echo "Starting $(hostname) backup process..."

rsync -aiR scripts config titan-mad:/DataVolume/WDConfiguration/io/

DISK_DEV=/dev/mmcblk0

TARGET_FILE=$(hostname)_backup_$(date +%Y%m%d).gz
TARGET_USER=root
TARGET_SERVER=titan-mad
TARGET_DEST=/DataVolume/WDConfiguration/$TARGET_FILE

# List of services to stop
SERVICE_LIST="nginx openvpn"

# Sync disks
sync; sync

# Shutdown services
echo "Shutdown services..."
for sv in $SERVICE_LIST; do
  echo " - $sv"
  service $sv stop
done

# Performing backup
echo "Generating backup..."
sdSize=$(blockdev --getsize64 $DISK_DEV)
dd if=$DISK_DEV bs=1M conv=sync,noerror iflag=fullblock | pv -tpreb -s $sdSize | gzip - | ssh ${TARGET_USER}@${TARGET_SERVER} dd of=$TARGET_DEST

# Restart services
echo "Restart services..."
for sv in $SERVICE_LIST; do
  echo " - $sv"
  service $sv start
done

