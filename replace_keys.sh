#!/bin/bash

if [[ $# -ne 1 ]] || [ ! -f $1 ]; then
  echo "Usage: $0 <keys-file>"
  exit 1
fi

keys_file=$1

# Get server name (configuration fixed path)
server=$(grep @server@ $keys_file | cut -d '=' -f 2)
targetpath=/root/$server.cfg

# Creating path directory
rm -rf $targetpath && mkdir -p $targetpath

# Loop on files
for f in $(find $(dirname $0) -type f | grep -v .git); do

  target=$targetpath/$f

  mkdir -p $(dirname $target) && cp -v $f $target

  while read keyvalue; do
    key="$(echo $keyvalue | cut -d '=' -f 1)"
    val="$(echo $keyvalue | cut -d '=' -f 2-)"

    sed -i "s/@${key}@/${val}/g" $target

  done < <(grep -v "\#" $keys_file | grep -v "^$")

done

exit 0
