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
	local npm_root
	local claude_dir
	local install_script

	if command -v claude >/dev/null 2>&1; then
		echo "[INFO] Claude already installed at $(command -v claude); refreshing package"
	fi
	npm install -g --include=optional "${CLAUDE_NPM_PACKAGE}"

	npm_root="$(npm root -g)"
	claude_dir="${npm_root}/${CLAUDE_NPM_PACKAGE}"
	install_script="${claude_dir}/install.cjs"

	if [[ -f "${install_script}" ]]; then
		echo "[INFO] Running Claude postinstall manually"
		node "${install_script}"
	else
		echo "[WARN] Claude install script not found at ${install_script}"
	fi

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
	local version_output
	version_output="$(claude --version 2>&1)"
	local version_exit=$?
	local help_output
	help_output="$(claude --help 2>&1)"
	local help_exit=$?
	set -e

	echo "[INFO] claude --version exit code: ${version_exit}"
	if [[ ${version_exit} -eq 0 ]]; then
		echo "[INFO] Claude version output: ${version_output}"
		echo "[INFO] Claude smoke test passed"
		return 0
	fi

	echo "[INFO] claude --help exit code: ${help_exit}"
	if [[ ${help_exit} -eq 0 ]]; then
		echo "[INFO] Claude smoke test passed"
		return 0
	fi

	if printf '%s' "${help_output}" | grep -Eiq 'usage:|claude|commands:|options:'; then
		echo "[WARN] claude --help returned a non-zero exit code but printed usage text"
		echo "[INFO] Claude help output:"
		printf '%s\n' "${help_output}"
		echo "[INFO] Treating Claude smoke test as passed"
		return 0
	fi

	echo "[ERROR] Claude smoke test failed"
	echo "[ERROR] claude --version output:"
	printf '%s\n' "${version_output}"
	echo "[ERROR] claude --help output:"
	printf '%s\n' "${help_output}"
	return 1
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
