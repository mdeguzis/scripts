#!/bin/bash
# Installs common packages and services
# Preferred: termux-backup, https:g
# Provides a general agnostic setup

SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Base packages
echo "[INFO] Installing base packages"
pkg install \
	busybox \
	clang \
	coreutils \
	cronie \
	git \
	make \
	ncdu \
	openssh \
	python-pip \
	python \
	termux-services \
	termux-tools \
	tree \
	unzip \
	util-linux \
	vim \
	xz-utils \
	zstd

# https://wiki.termux.com/wiki/Termux-services
echo -e "\n[INFO] Activating services"
services=()
services+=("crond")
services+=("sshd")

for service in "${services[@]}";
do
	echo "[INFO] Checking for service ${service}"	
	if [[ $(pidof "${service}") == "" ]]; then
		echo "[INFO] Enabling and starting ${service}"
		sv-enable "${service}"
		sv up "${service}"
	else
		echo "[INFO] ${service} already running"
	fi
done

echo -e "\n[INFO] Fetching scripts"
if [[ ! -d "${HOME}/scripts" ]]; then
	cd "${HOME}"
	git clone https://github.com/mdeguzis/scripts
fi

cd "${SCRIPT_DIR}"
echo -e "\n[INFO] Configuring crontab"
if crontab -T "${SCRIPT_DIR}/user-crontab.txt"; then
	crontab "${SCRIPT_DIR}/user-crontab.txt"
fi

# https://wiki.termux.com/wiki/Termux-setup-storage
echo -e "\n[INFO] Configuring storage"
termux-setup-storage

echo -e "\n[INFO] Finishing up"

echo -e "\n[INFO] Running backup..."
termux-backup --force "${HOME}/storage/documents/backups/termux/termux-backup.tar.gz"


