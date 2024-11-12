#!/bin/bash
date_stamp=$(date +%Y%m%d-T%H:%m:%S)

files=()
files+=("KeePass/mtd-keepass.kdbx")

for f in ${files[@]};
do
    cp ~/google-drive/${f} ~/google-drive/${f}-${date_stamp}.bak
    # Trip old backups
    find ~/google-drive/${f}-* -mtime +14 -delete
done
