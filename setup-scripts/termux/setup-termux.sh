#!/bin/bash
# Installs common packages and services
# Preferred: termux-backup, termux-services
# Provides a general agnostic setup, including a Termux-native Claude install.

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname "$0")" >/dev/null 2>&1
	pwd -P
)"

CLAUDE_NPM_PACKAGE="@anthropic-ai/claude-code"
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

install_claude() {
	echo -e "\n[INFO] Installing Claude Code\n"
	if command -v claude >/dev/null 2>&1; then
		echo "[INFO] Claude already installed at $(command -v claude); refreshing package"
	fi
	npm install -g "${CLAUDE_NPM_PACKAGE}"
	if command -v claude >/dev/null 2>&1; then
		echo "[INFO] Claude available at $(command -v claude)"
	else
		echo "[WARN] Claude package installed but command not found on PATH yet"
	fi
}

verify_claude() {
	echo -e "\n[INFO] Verifying Claude installation\n"
	if ! command -v claude >/dev/null 2>&1; then
		echo "[ERROR] Claude binary not found on PATH after install"
		return 1
	fi

	set +e
	claude --help >/dev/null 2>&1
	local claude_exit=$?
	set -e

	echo "[INFO] claude --help exit code: ${claude_exit}"
	if [[ ${claude_exit} -ne 0 ]]; then
		echo "[ERROR] Claude smoke test failed"
		return "${claude_exit}"
	fi

	echo "[INFO] Claude smoke test passed"
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
install_claude
verify_claude

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
termux-backup --force "${HOME}/storage/documents/backups/termux/termux-backup.tar.gz"
