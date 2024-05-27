#!/bin/bash

target_folder=$1

# This script seaches the target folder in this directory for CHD
# files and autocreate the correct strucutre if the ROM ZIP is found
# Point this script at your mame folde root, such as ~/Emulation/roms/mame
#
# For example
# mame/roms/this.zip
# mame/roms/this/this.chd
# 
# Updating existing:
# https://www.reddit.com/r/Roms/comments/v8cy1o/easiest_way_to_update_your_mame_roms/

if [[ -z "${target_folder}" ]]; then
	echo "[ERROR] Missing target folder as argument 1!"
	exit 1
fi
if [[ ! -d "${target_folder}" ]]; then
	echo "[ERROR] $target_folder does not exist!"
	exit 1
fi

echo "[INFO] checking $target_folder for MAME CHD files..."
find $target_folder -name "*.chd" -print0 | while read -d $'\0' chd
do
	chd_short_name=$(basename "${chd}")
	echo "[INFO] Analyzing CHD file '${chd_short_name}'"
	game_name=$(basename "${chd}" | sed 's/.chd//')
	game_zip=$(find "${target_folder}" -name "${game_name}.zip")
	if [[ -n "${game_zip}" ]]; then
		base_folder=$(dirname "${game_zip}")
		game_folder="${base_folder}/${game_name}"
		echo "[INFO] Found game zip: '${game_zip}'"
		echo "[INFO] Creating folder '${game_folder}' and linking ${chd_short_name}"
		mkdir -p "${game_folder}"
		ln -sfv "${chd}" "${game_folder}/${chd_short_name}"
		exit 0
	fi
done
