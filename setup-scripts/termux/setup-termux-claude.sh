#!/bin/bash
# Claude Code setup for native Termux, with Android-specific patching and
# proot fallback guidance.

set -euo pipefail

append_if_missing() {
	local file="$1"
	local line="$2"
	touch "${file}"
	if ! grep -Fqx "${line}" "${file}"; then
		printf '%s\n' "${line}" >>"${file}"
	fi
}

setup_termux_tmp_env() {
	local env_file
	for env_file in "${HOME}/.profile" "${HOME}/.zshenv"; do
		touch "${env_file}"
		append_if_missing "${env_file}" '# Added by termux/setup-termux-claude.sh for Claude Code on Termux'
		append_if_missing "${env_file}" 'if [ -n "$PREFIX" ] && [ -d "$PREFIX/tmp" ]; then export TMPDIR="${TMPDIR:-$PREFIX/tmp}"; fi'
		append_if_missing "${env_file}" 'if [ -n "${TMPDIR:-}" ]; then export CLAUDE_CODE_TMPDIR="${CLAUDE_CODE_TMPDIR:-$TMPDIR}"; fi'
	done
}

ensure_npm_prefix() {
	echo -e "\n[INFO] Configuring npm global prefix for Claude\n"
	mkdir -p "${HOME}/.npm-global"
	npm config set prefix "${HOME}/.npm-global"
	export PATH="${HOME}/.npm-global/bin:${PATH}"
}

setup_claude_helpers() {
	local rc_file
	for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
		append_if_missing "${rc_file}" '# Added by termux/setup-termux-claude.sh'
		append_if_missing "${rc_file}" 'if [ -d "$HOME/.npm-global/bin" ]; then export PATH="$HOME/.npm-global/bin:$PATH"; fi'
		append_if_missing "${rc_file}" "alias termux-ubuntu='proot-distro login ubuntu'"
		append_if_missing "${rc_file}" "alias termux-claude-help='cat \"\$HOME/CLAUDE-TERMUX-SETUP.txt\"'"
		append_if_missing "${rc_file}" "alias termux-claude-patch='bash \"\$HOME/.scripts/termux-claude-patch.sh\" --verbose'"
		append_if_missing "${rc_file}" 'if [ -f "$HOME/.scripts/termux-claude-patch.sh" ]; then source "$HOME/.scripts/termux-claude-patch.sh"; fi'
	done
}

install_termux_claude_patch_helper() {
	local script_dir="${HOME}/.scripts"
	local patch_script="${script_dir}/termux-claude-patch.sh"
	mkdir -p "${script_dir}"
	cat >"${patch_script}" <<'EOF'
#!/bin/bash

set -u

verbose=0
if [[ "${1:-}" == "--verbose" ]]; then
	verbose=1
fi

log() {
	if [[ "${verbose}" -eq 1 ]]; then
		echo "[termux-claude-patch] $*"
	fi
}

if [[ -n "${PREFIX:-}" && -d "${PREFIX}/tmp" ]]; then
	export TMPDIR="${TMPDIR:-${PREFIX}/tmp}"
	export CLAUDE_CODE_TMPDIR="${CLAUDE_CODE_TMPDIR:-${TMPDIR}}"
fi

if ! command -v npm >/dev/null 2>&1; then
	log "npm not found; skipping Claude patch helper"
	return 0 2>/dev/null || exit 0
fi

npm_root="$(npm root -g 2>/dev/null || true)"
if [[ -z "${npm_root}" ]]; then
	log "npm root -g unavailable; skipping Claude patch helper"
	return 0 2>/dev/null || exit 0
fi

claude_dir="${npm_root}/@anthropic-ai/claude-code"
cli_js="${claude_dir}/cli.js"

if [[ ! -f "${cli_js}" ]]; then
	log "Claude CLI not installed at ${claude_dir}; nothing to patch"
	return 0 2>/dev/null || exit 0
fi

if command -v rg >/dev/null 2>&1; then
	rg_target="${claude_dir}/vendor/ripgrep/arm64-android/rg"
	mkdir -p "$(dirname "${rg_target}")"
	if [[ ! -e "${rg_target}" || ! -x "${rg_target}" ]]; then
		ln -sf "$(command -v rg)" "${rg_target}"
		log "linked system rg to ${rg_target}"
	fi
else
	log "system rg not found; install Termux ripgrep to fix Grep/Glob"
fi

if grep -q "__TERMUX_TMPDIR_PATCHED__" "${cli_js}" 2>/dev/null; then
	log "cli.js already patched"
	return 0 2>/dev/null || exit 0
fi

if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
	log "python missing; cannot patch cli.js"
	return 0 2>/dev/null || exit 0
fi

python_bin="$(command -v python3 || command -v python)"

"${python_bin}" - "${cli_js}" <<'PY'
import pathlib
import sys

cli_path = pathlib.Path(sys.argv[1])
text = cli_path.read_text(encoding="utf-8")
original = text

tmp_expr = '(process.env.CLAUDE_CODE_TMPDIR||process.env.TMPDIR||process.env.TEMP||process.env.TMP||"/tmp")'
replacements = [
    ('process.env.CLAUDE_TMPDIR||"/tmp/claude"', f'process.env.CLAUDE_TMPDIR||{tmp_expr}+"/claude"'),
    ('process.env.CLAUDE_CODE_TMPDIR||"/tmp"', tmp_expr),
    ('CLAUDE_CODE_TMPDIR||(c8()==="windows"?hIz():"/tmp")', f'CLAUDE_CODE_TMPDIR||(c8()==="windows"?hIz():{tmp_expr})'),
    ('return`/tmp/claude-mcp-browser-bridge-', f'return`${tmp_expr}/claude-mcp-browser-bridge-'),
    ('z=`/tmp/${K}`', f'z=`${{{tmp_expr}}}/${{K}}`'),
    ('"/tmp/claude","/private/tmp/claude"', f'"/tmp/claude","/private/tmp/claude",({tmp_expr})+"/claude"'),
]

applied = 0
for old, new in replacements:
    if old in text and new not in text:
        text = text.replace(old, new)
        applied += 1

if applied and "__TERMUX_TMPDIR_PATCHED__" not in text:
    text += "\n// __TERMUX_TMPDIR_PATCHED__\n"

if text != original:
    backup = cli_path.with_suffix(cli_path.suffix + ".termux.bak")
    if not backup.exists():
        backup.write_text(original, encoding="utf-8")
    cli_path.write_text(text, encoding="utf-8")
    print(f"patched {applied} Claude cli.js temp-path pattern(s)")
else:
    print("no Claude cli.js temp-path changes needed")
PY

log "finished Claude patch helper"
return 0 2>/dev/null || exit 0
EOF
	chmod +x "${patch_script}"
}

setup_claude_guidance() {
	local guidance_file="${HOME}/CLAUDE-TERMUX-SETUP.txt"
	cat <<'EOF' | tee "${guidance_file}"

[INFO] Claude Code on Termux currently works best with npm-global + Termux-specific patching.

Current repo findings:
- #3569 was a Raspberry Pi / wrong-Node-arch issue, not a Termux root cause.
- Native installer still does not fit Termux/Bionic; npm-global remains the
  viable install method on Android/Termux.
- Current Termux blockers are mostly:
  1. hardcoded /tmp paths in cli.js
  2. missing vendor/ripgrep/arm64-android/rg
  3. optional image-reading sharp/android issues

Recommended native Termux setup:

1. Base packages:
   pkg install -y nodejs-lts python ripgrep

2. Install Claude Code:
   npm install -g @anthropic-ai/claude-code

3. Open a new shell, or source your rc files:
   source ~/.profile
   source ~/.bashrc

4. Patch Claude for Termux:
   termux-claude-patch

5. Verify:
   claude --version
   claude doctor

Expected doctor notes:
- install method may still mention native in config
- currently running should be npm-global
- Search should be OK (rg)

Optional image workaround if image reading fails on Android sharp:
   npm install -g @img/sharp-wasm32 sharp --force

Fallback if native Termux breaks again:

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
- termux-claude-patch

This note was also written to:
  ~/CLAUDE-TERMUX-SETUP.txt
EOF
}

echo -e "\n[INFO] Setting up Claude Code for Termux\n"
setup_termux_tmp_env
ensure_npm_prefix
install_termux_claude_patch_helper
setup_claude_helpers
setup_claude_guidance
