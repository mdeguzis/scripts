#!/bin/bash
# Installs common packages and services
# Preferred: termux-backup, termux-services
# Provides a general agnostic setup

SCRIPT_DIR="$(
	cd -- "$(dirname "$0")" >/dev/null 2>&1
	pwd -P
)"

# Base packages
echo -e "\n[INFO] Installing base packages\n"
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
	rust \
	termux-services \
	termux-tools \
	tree \
	unzip \
	util-linux \
	vim \
	xz-utils \
	zstd

echo -e "\n[INFO] Running upgrade"
pkg upgrade

echo -e "\n[INFO] Installing Python packages\n"
pip install \
	bs4 \
	isodate \
	cryptography \
	pillow \
	requests

# https://wiki.termux.com/wiki/Termux-services
echo -e "\n[INFO] Activating services\n"
services=()
services+=("crond")
services+=("sshd")

for service in "${services[@]}"; do
	echo "[INFO] Checking for service ${service}"
	if [[ $(pidof "${service}") == "" ]]; then
		echo "[INFO] Enabling and starting ${service}"
		sv-enable "${service}"
		sv up "${service}"
	else
		echo "[INFO] ${service} already running"
	fi
done

repos=()
repos+=("mdeguzis/scripts")
repos+=("mdeguzis/python")

for repo in "${repos[@]}"; do
	repo_user=$(echo "${repo}" | cut -d'/' -f1)
	repo_name=$(echo "${repo}" | cut -d'/' -f2)
	echo -e "\n[INFO] Checking for repo ${repo}"
	if [[ ! -d "${HOME}/${repo_name}" ]]; then
		git clone "{${repo}" "${HOME}/scripts"
		git clone "https://github.com/${repo_user}/${repo_name}" "${HOME}/${repo_name}"
	else
		git -C "${HOME}/scripts" pull --rebase
	fi
done

cd "${SCRIPT_DIR}"
echo -e "\n[INFO] Attempting to configure crontab"
if crontab -T "${SCRIPT_DIR}/user-crontab.txt"; then
	echo "[INFO] Installing crontab"
	crontab "${SCRIPT_DIR}/user-crontab.txt"
fi

# https://wiki.termux.com/wiki/Termux-setup-storage
echo -e "\n[INFO] Configuring storage"
termux-setup-storage

echo -e "\n[INFO] Finishing up"

echo -e "\n[INFO] Running backup..."
termux-backup --force "${HOME}/storage/documents/backups/termux/termux-backup.tar.gz"
