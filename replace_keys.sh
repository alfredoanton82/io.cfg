#!/bin/bash

if [[ $# -ne 2 ]] || [ ! -f $1 ]; then
  echo "Usage: $0 <keys-file> <target-path>"
  exit 1
fi

keys_file=$1
targetpath=$2

# Goto configuration directory
cd $(dirname $0)

# Creating path directory
rm -rf $targetpath && mkdir -p $targetpath

# Loop on files
for f in $(find . -type f | grep -v .git); do

  target=$targetpath/$f

  mkdir -p $(dirname $target) && cp -v $f $target

  for keyvalue in $(grep -v "\#" $keys_file | grep -v "^$"); do
    key=$(echo $keyvalue | cut -d "=" -f 1)
    val=$(echo $keyvalue | cut -d "=" -f 2)

    sed -i "s/@${key}@/${val}/g" $target

  done

done

exit 0
