#!/bin/bash
# Installs common packages and services
# Preferred: termux-backup, termux-services
# Provides a general agnostic setup for Termux, including a supported Claude
# workflow via proot-distro instead of the now-broken native Android path.

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
	make \
	ncdu \
	nodejs-lts \
	openssh \
	proot-distro \
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
)

append_if_missing() {
	local file="$1"
	local line="$2"
	touch "${file}"
	if ! grep -Fqx "${line}" "${file}"; then
		printf '%s\n' "${line}" >>"${file}"
	fi
}

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

		append_if_missing "${rc_file}" '# Added by termux/setup-termux.sh'
		append_if_missing "${rc_file}" 'if [ -d "$HOME/.npm-global/bin" ]; then export PATH="$HOME/.npm-global/bin:$PATH"; fi'
		append_if_missing "${rc_file}" "if [ -x \"\$HOME/.local/bin/mise\" ]; then eval \"\$(\"\$HOME/.local/bin/mise\" activate ${shell_name})\"; fi"
	done
}

ensure_npm_prefix() {
	echo -e "\n[INFO] Configuring npm global prefix\n"
	mkdir -p "${HOME}/.npm-global"
	npm config set prefix "${HOME}/.npm-global"
	export PATH="${HOME}/.npm-global/bin:${PATH}"
}

setup_claude_helpers() {
	local rc_file
	for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
		append_if_missing "${rc_file}" "alias termux-ubuntu='proot-distro login ubuntu'"
		append_if_missing "${rc_file}" "alias termux-claude-help='cat \"\$HOME/CLAUDE-TERMUX-SETUP.txt\"'"
	done
}

setup_claude_proot_guidance() {
	local guidance_file="${HOME}/CLAUDE-TERMUX-SETUP.txt"
	cat <<'EOF' | tee "${guidance_file}"

[INFO] Claude Code should be run in proot-distro Ubuntu on Termux.

Why:
- Older Claude builds could run on native Termux.
- Current Claude versions require newer clients and newer clients reject
  platform "android arm64".
- Native Termux is therefore no longer a stable/supported Claude path.

Recommended setup:

1. Install Ubuntu in proot:
   proot-distro install ubuntu

2. Enter Ubuntu:
   proot-distro login ubuntu

3. Inside Ubuntu, install dependencies:
   apt update
   apt install -y curl git nodejs npm python3

4. Install Claude Code inside Ubuntu:
   npm install -g @anthropic-ai/claude-code
   claude --version

5. Work from a shared Termux folder, for example:
   cd /data/data/com.termux/files/home/src

Convenience commands added to your shell:
- termux-ubuntu
- termux-claude-help

This note was also written to:
  ~/CLAUDE-TERMUX-SETUP.txt
EOF
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

ensure_npm_prefix
setup_claude_helpers
setup_claude_proot_guidance

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
