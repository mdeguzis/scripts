#!/bin/bash
# Installs common packages and services
# Preferred: termux-backup, termux-services
# Provides a general agnostic setup for Termux and then hands off Claude Code
# setup to the dedicated helper script.

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname "$0")" >/dev/null 2>&1
	pwd -P
)"

PYTHON_PACKAGES=(
	bs4
	cryptography
	isodate
	pillow
	requests
)
BASE_PACKAGES=(
	busybox \
	ca-certificates \
	clang \
	coreutils \
	cronie \
	curl \
	git \
	jq \
	make \
	ncdu \
	nodejs-lts \
	openssh \
	proot-distro \
 python-pillow \
	python-pip \
	python \
	ripgrep \
	rust \
	rsync \
	termux-services \
	termux-tools \
	tree \
	unzip \
	util-linux \
	uv \
	vim \
	xz-utils \
	zip \
	zstd
)

repair_shell_rc() {
	local rc_file
	for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
		local shell_name="bash"
		touch "${rc_file}"
		if [[ "${rc_file}" == *".zshrc" ]]; then
			shell_name="zsh"
		fi

		if grep -Fq '/.local/bin/mise' "${rc_file}"; then
			cp "${rc_file}" "${rc_file}.bak"
			sed -i '\#/.local/bin/mise#d' "${rc_file}"
		fi

		if ! grep -Fqx '# Added by termux/setup-termux.sh' "${rc_file}"; then
			printf '%s\n' '# Added by termux/setup-termux.sh' >>"${rc_file}"
		fi
		if ! grep -Fqx 'if [ -d "$HOME/.npm-global/bin" ]; then export PATH="$HOME/.npm-global/bin:$PATH"; fi' "${rc_file}"; then
			printf '%s\n' 'if [ -d "$HOME/.npm-global/bin" ]; then export PATH="$HOME/.npm-global/bin:$PATH"; fi' >>"${rc_file}"
		fi
		if ! grep -Fqx "if [ -x \"\$HOME/.local/bin/mise\" ]; then eval \"\$(\"\$HOME/.local/bin/mise\" activate ${shell_name})\"; fi" "${rc_file}"; then
			printf '%s\n' "if [ -x \"\$HOME/.local/bin/mise\" ]; then eval \"\$(\"\$HOME/.local/bin/mise\" activate ${shell_name})\"; fi" >>"${rc_file}"
		fi
	done
}

# Base packages
echo -e "\n[INFO] Running upgrade\n"
pkg update -y
pkg upgrade -y

echo -e "\n[INFO] Installing base packages\n"
pkg install -y "${BASE_PACKAGES[@]}"

echo -e "\n[INFO] Repairing shell rc files\n"
repair_shell_rc

echo -e "\n[INFO] Installing Python packages\n"
python -m pip install --verbose --upgrade-strategy only-if-needed "${PYTHON_PACKAGES[@]}"

echo -e "\n[INFO] Running Claude Code Termux helper\n"
bash "${SCRIPT_DIR}/setup-termux-claude.sh"

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
		git clone "https://github.com/${repo_user}/${repo_name}" "${HOME}/${repo_name}"
	else
		git -C "${HOME}/${repo_name}" pull --rebase
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
bash -x "$(command -v termux-backup)" --force "${HOME}/storage/documents/backups/termux/termux-backup.tar.gz"
