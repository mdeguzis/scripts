#!/bin/bash

set -e

torrent=$1
dest=$2

if [[ ! -f "/usr/bin/transmission-cli" ]]; then
	echo "transmission-cli is missing! Please install it"
	exit 1
fi

if [[ -z $torrent ]]; then
	echo "Missing torrent link as argument 1!"
	exit 1
fi
if [[ -z $dest ]]; then
	echo "Missing destination folder as argument 2!"
	exit 1
fi

if [[ ! -d "$dest" ]]; then
	echo "Destination dir does not exist or is not a folder! Got: '$dest'"
	exit 1
fi

/usr/bin/transmission-cli \
	--download-dir "${dest}" \
	"$torrent"
