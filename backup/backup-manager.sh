#!/bin/bash
# Description: Cloud backup manager

# This causes the script to fail when running as the systemd service, check later...
#set -e

# Defaults
CURDIR="${PWD}"
CONFIG="${HOME}/.config/backup-configs/home-backup"
DATE=$(date +%Y%m%d-%H%M%S)
GIT_ROOT=$(git rev-parse --show-toplevel)
LOG_FILE="/tmp/backup-mgr-${DATE}.log"
PIDFILE="/tmp/home-backup-rclone.pid"
HOSTNAME=$(cat /etc/hostname)
REMOTE="${REMOTE:-onedrive}"
BACKUP_LOG="/tmp/home-backup-job.log"

if [[ -z "${HOSTNAME}" ]]; then
	echo "[ERROR] Could not set hostname for remote!"
	exit 1
fi

# Where to start filtering from
START_PATH="/"

function finish {
  echo "[INFO] Script terminating. Exit code $?"
}

function show_help() {
	cat<<-HELP_EOF
	--help|-h			Show this help page
	--install|-i			Install backup manager
	--dry-run			Dry-run test sync
	--uninstall|-u			Uninstall backup manager
	--list-remotes|-l		List available remotes
	--backup|-b			Run backup
	--status|-s			Backup service status
	--remote-name			The name of the rclone remote to use

	HELP_EOF
	exit 0
}

function install_rclone() {
	# https://rclone.org/install/
	echo -e "\n[INFO] Installing rclone binary"
	
	# Unpack
	cd /tmp
	curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
	unzip -o rclone-current-linux-amd64.zip
	cd rclone-*-linux-amd64

	# Install
	sudo cp -v rclone "${HOME}/.local/bin/rclone"
	echo "[INFO] rclone has been installed to ${HOME}/.local/bin/rclone"

}

function configure() {
	local REMOTE=$1

	echo "[INFO] Checking for existence of remote ${REMOTE}"
	if ! ${HOME}/.local/bin/rclone config show | grep -qwE "\[${REMOTE}\]"; then
		echo -e "\n[INFO] Configuring rclone remote. Follow the directions at https://rclone.org/s3/"
  		echo -e "Existing remotes:\n$(rclone listremotes)\n"
		echo "[INFO] Please name the remote ${REMOTE}. Press ENTER to continue"
		read
		rclone config
	fi

	# Create remote folder if it does not exist
	if ! ${HOME}/.local/bin/rclone lsd ${REMOTE}: | grep -q "rclone-backups"; then
		echo "[INFO] Creating rlcone-backups root at remote '${REMOTE}'"
		${HOME}/.local/bin/rclone mkdir ${REMOTE}:rclone-backups
	fi
	
	# Copy filter files to ${CONFIG} var location
	mkdir -p "${HOME}/.config/backup-configs/home-backup"
	cp -v "backup-manager.sh" "${HOME}/.config/backup-configs/home-backup"
	cp -v "filter-from.txt" "${HOME}/.config/backup-configs/home-backup"
	cp -v "exclude-list.txt" "${HOME}/.config/backup-configs/home-backup"

	# Add env-variable based paths that change from system to system,
	# e.g. $HOME
	# These paths are conditional based on what system I am backing up
	# TODO: Put this config of paths somewhere else and load it! (JSON?)
	paths=()

	# Filter
	# Excludes take priority, add them first
	for p in $(cat "exclude-list.txt");
	do
		this_path=$(echo "${p}" | sed "s|\${HOME}|${HOME}|")
		echo "- ${this_path}" >> "${HOME}/.config/backup-configs/home-backup/filter-from.txt"
	done	

	# Add a list of broken symlinks as excludes so they don't break rclone using --copy-links
	echo "[INFO] Checking paths for broken symlimks"
	for sync_config in $(ls sync-configs);
	do
		for p in $(cat "sync-configs/${sync_config}");
		do
			this_path=$(echo "${p}" | sed "s|**||;s|\${HOME}|${HOME}|")
			# If path does not exist, exclude (broken symlink)
			for f in $(find "${this_path}" -type l ! -exec test -e {} \; -print);
			do
				echo "- ${f}" >> "${HOME}/.config/backup-configs/home-backup/filter-from.txt"
			done
		done
	done

	# pad
	echo >> "${HOME}/.config/backup-configs/home-backup/filter-from.txt"

	# Check sync-configs dir for any paths we want to sync
	# Remove or configure files in this directory to remove syncs
	for sync_config in $(ls sync-configs);
	do
		echo "[INFO] Configuring save config: ${sync_config}"
		for p in $(cat "sync-configs/${sync_config}");
		do
			paths+=("${p}")
		done
	done

	# Check and configure paths
	for this_path in ${paths[@]};
	do
		# TODO fix... idk why ${HOME} doesn't resolve in this script when checking..
		# Checking the conditional in bash is fine, but it doesn't work below
		# Resolve the path for now
		this_path=$(echo "${this_path}" | sed "s|\${HOME}|${HOME}|")

		echo "[INFO] Checking if path or file exists: '${this_path}'"
		if echo \'${this_path}\' | grep -q '*'; then 
			# Add glob
			regex=$(basename "${this_path}")
			base_path=$(dirname "${this_path}")
			if [[ -d "${base_path}" ]]; then
				echo "[INFO] Analyzing results of glob '${regex}' for path ${base_path} to filter-from.txt"
				find "${base_path}" -name \""${regex}"\" -exec echo "+ {}" \; >> "${HOME}/.config/backup-configs/home-backup/filter-from.txt" \; 2> /dev/null
			fi

		elif [[ -d "${this_path}" ]]; then
			echo "[INFO] Adding directory '${this_path}' to filter-from.txt"
			echo "+ ${this_path}/**" >> "${HOME}/.config/backup-configs/home-backup/filter-from.txt"

		elif [[ -f "${this_path}" ]]; then 
			echo "[INFO] Adding file '${this_path}' to filter-from.txt"
			echo "+ ${this_path}" >> "${HOME}/.config/backup-configs/home-backup/filter-from.txt"

		fi
	done

	# Last line of this file MUST be '- **' (exclude the rest) as otherwise you will start backing up the entire system!
	echo -e "\n- **" >> "${HOME}/.config/backup-configs/home-backup/filter-from.txt"
}

rclone_stop_service(){
    systemctl --user stop home-backup.timer
    systemctl --user stop home-backup.service
}

rclone_start_service(){
    systemctl --user start home-backup.timer
}

function create_service() {
	echo "[INFO] Copying systemd configs"
	cp -v "systemd/home-backup.service" "${HOME}/.config/systemd/user/"
	cp -v "systemd/home-backup.timer" "${HOME}/.config/systemd/user/"

	# Replace home var
	sed -i "s|HOME_DIR|${HOME}|g"  "${HOME}/.config/systemd/user/home-backup.service"

	echo "[INFO] Enabling systemd service"
	systemctl --user enable home-backup.service

	echo "[INFO] Enabling SaveBackup 15 minute timer service"
	systemctl --user enable home-backup.timer

	echo "[INFO] Starting Timer"
	rclone_start_service "home-backup"
}

function disable_service() {
	echo "[INFO] Removing systemd configs"
	rm -fv "home-backup.service" "${HOME}/.config/systemd/user/home-backup.service"
	rm -fv  "home-backup.timer" "${HOME}/.config/systemd/user/home-backup.timer"

	echo "[INFO] Removing home-backup service"
	systemctl --user stop home-backup.service
	systemctl --user disable home-backup.service

	echo "[INFO] Removing SaveBackup 15 minute timer service"
	systemctl --user stop home-backup.timer
	systemctl --user disable home-backup.timer
}

main() {
	while :; do
		case $1 in
			--install|-i)
				INSTALL="true"
				;;

			--uninstall|-u)
				UNINSTALL="true"
				;;

			--backup|-b)
				BACKUP="true"
				;;

			--dry-run)
				DRY_RUN="true"
				RCLONE_OPTS="--dry-run"
				;;

			--list-remotes|-l)
				LIST_REMOTES="true"
				;;

			--status|-s)
				STATUS="true"
				;;

    			--remote-name)
				if [[ -n "$2" ]]; then
					REMOTE="$2"
					shift
				else
					echo -e "ERROR: This option requires an argument.\n" >&2
					exit 1
				fi
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
	echo

	if [[ ${LIST_REMOTES} == "true" ]]; then
		echo -e "\n[INFO] Listing available remotes to use:\n"
		echo -e "$(${HOME}/.local/bin/rclone config show | grep -E '^\[.*]$' | sed 's/\[//g;s/\]//g')\n"
		exit 0
	fi

	if [[ ${INSTALL} == "true" ]]; then
		if [[ ! -f "${HOME}/.local/bin/rclone" ]]; then
			install_rclone
		fi	

		configure "${REMOTE}"
		create_service

	elif [[ ${UNINSTALL} == "true" ]]; then
		disable_service
		exit 0

	elif [[ ${STATUS} == "true" ]]; then
		systemctl --user status home-backup.service
		exit 0
	fi

	if [[ ${BACKUP} == "true" ]]; then
		echo "[INFO] Running backup..."
		trap finish EXIT

		# PID handling
		if [ -f "$PIDFILE" ]; then
		  PID=$(cat "$PIDFILE")
		  ps -p "$PID" > /dev/null 2>&1
		  if [ $? -eq 0 ]; then
		    echo "[ERROR] Process already running"
		    exit 1
		  else
		    ## Process not found assume not running
		    echo $$ > "$PIDFILE"
		    if [ $? -ne 0 ]; then
		      echo "[ERROR] Could not create PID file"
		      exit 1
		    fi
		  fi
		else
		  echo $$ > "$PIDFILE"
		  if [ $? -ne 0 ]; then
		    echo "[ERROR] Could not create PID file"
		    exit 1
		  fi
		fi

		# Run clone
		# Need full path for rclone when running under system sevie
		# ChimeraOS will whipe the system bits on upgrade, so don't use /usr/bin/rclone...
		# Need to find a spot that isn't wiped

		echo "[INFO] Running rclone to ${BACKUP_NAME}/${HOSTNAME}"
		cmd="${HOME}/.local/bin/rclone copy --verbose --verbose --copy-links --filter-from ${HOME}/.config/backup-configs/home-backup/filter-from.txt ${START_PATH} ${REMOTE}:rclone-backups/${HOSTNAME} -P ${RCLONE_OPTS}"
		echo "[INFO] Running cmd: ${cmd}"
		sleep 3
		#eval "${cmd}" 2>&1 | tee "${BACKUP_LOG}"
		eval "${cmd}"

		if [ $? -eq 0 ]; then
			echo "[INFO] Cleaning PID file $PIDFILE"
			rm -f $PIDFILE
			exit 0
		else
			echo "[INFO] Backup failed! See ${LOG_FILE}"
			exit 1
		fi

	fi
}

# Start and log
main "$@" 2>&1 | tee "${LOG_FILE}"

# Trim logs
echo "[INFO] Trimming logs"
find /tmp -name "${LOG_FILE}*" -mtime 14 -exec -delete \; 2>/dev/null

echo "[INFO] Log: ${LOG_FILE}"
echo "[INFO] clone operation log: ${BACKUP_LOG}"

