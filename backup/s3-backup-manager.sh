#!/bin/bash
# Description: Cloud backup manager

set -e -o pipefail

# Defaults
CURDIR="${PWD}"
DATE=$(date +%Y%m%d-%H%M%S)
GIT_ROOT=$(git rev-parse --show-toplevel)
LOG_FILE="/tmp/backup-mgr-${DATE}.log"
LINE="==========================================================="

function show_help() {
	cat<<-HELP_EOF
	--help|-h			Show this help page
	--install			Install rclone
	--configure			Configure backup to S3

	HELP_EOF
	exit 0
}

function install_rclone() {
	# https://rclone.org/install/
	echo -e "\n[INFO] Installing rclone binary"
	
	# Unpack
	cd /tmp
	curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
	unzip rclone-current-linux-amd64.zip
	cd rclone-*-linux-amd64

	# Install
	sudo cp -v rclone /usr/bin/
	sudo chown root:root /usr/bin/rclone
	sudo chmod 755 /usr/bin/rclone
	sudo mkdir -p /usr/local/share/man/man1
	sudo cp rclone.1 /usr/local/share/man/man1/
	#sudo mandb
	cd "${CURDIR}"

	echo "[INFO] rclone has been installed to /usr/bin/rclone"
}

main() {
	cat<<-EOF
	${LINE}
	S3 Backup Manager
	${LINE}
	EOF

	while :; do
		case $1 in
			--install|-i)
				INSTALL="true"
				;;

			--configure|-c)
				CONFIGURE="true"
				;;

			--backup|-z)
				if [[ -n $2 ]]; then
					TARGET="$2"
				else
					echo "[ERROR] An argument must be passed!"
					exit 1
				fi
				shift
				;;

			--help|-h)
				show_help;
				;;

			--)
				# End of all options.
				shift
				break
			;;

			-?*)
				printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
			;;

			*)
				# Default case: If no more options then break out of the loop.
				break

		esac

		# shift args
		shift
	done

	if [[ ${INSTALL} == "true" ]]; then
		install_rclone
	fi	
	if [[ ${CONFIGURE} == "true" ]]; then
		/usr/bin/rclone config
	fi	

}

# Start and log
main "$@" 2>&1 | tee "${LOG_FILE}"
echo "[INFO] Log: ${LOG_FILE}"

# Trim logs
find /tmp -name "${LOG_FILE}*" -mtime 14 -exec -delete \; 2>/dev/null

