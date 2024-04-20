#!/bin/bash
# Description: Fixes up symlinks:
#   1. Replace any /home/<user>/ with $HOME
#

# Replace with argument parser
target_path=$1
target_user=$2

function process () {
	local link=$1
	local target_user=$2

	echo -e "\n[INFO] Updating symlink: ${link}"
	local target=$(ls -la "${link}" | awk -F' -> ' '{print $2}')
	echo "[INFO] Link target: ${target}"

	# Has /home/<user> to update?
	if echo "${link}" | grep -q "/home"; then
		old_homepath=$(echo "${link}" | awk -F'/' '{print "/" $2 "/" $3}')
		if [[ -n "${target_user}" ]]; then
			new_link=$(echo "${link}" | sed "s|$USER|$target_user|g")
			new_target=$(echo "${target}" | sed "s|$USER|$target_user|g")
			#echo "[INFO] New link will be: ${new_target} -> ${new_link}"
			ln -sfv "${new_target}" "${new_link}"
		fi
	fi
}
export -f process

if [[ -z "${target_path}" ]]; then
	echo "[ERROR] Please provide the root path to scan as argument 1."
	exit 1
fi

echo "[INFO] Scanning and repairing path: ${target_path}"
find "${target_path}" -type l -exec bash -c 'process "{}" "deck"' \;

