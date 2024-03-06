#!/bin/bash
# Description: Cloud backup manager

# Defaults
CURDIR="${PWD}"
CONFIG="${HOME}/.config/home-backup"
DATE=$(date +%Y%m%d-%H%M%S)
GIT_ROOT=$(git rev-parse --show-toplevel)
LOG_FILE="/tmp/backup-mgr-${DATE}.log"
PIDFILE="/tmp/rclone.pid"
HOSTNAME=$(cat /etc/hostname)

if [[ -z "${HOSTNAME}" ]]; then
	echo "[ERROR] Could not set hostname for remote!"
	exit 1
fi

# Where to start filtering from
START_PATH="/"

function finish {
  echo "Script terminating. Exit code $?"
}

function show_help() {
	cat<<-HELP_EOF
	--help|-h			Show this help page
	--install			Install rclone
	--backup			Run backup
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
	unzip -o rclone-current-linux-amd64.zip
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

function configure() {
	if ! rclone config show | grep -qw "\[home-backup-gdrive\]"; then
		echo -e "\n[INFO] Configuring rclone remote. Follow the directions at https://rclone.org/s3/"
		echo "[INFO] Please name the remote 'home-backup-gdrive'. Press ENTER to continue"
		read
		rclone config
	fi

	# Copy filter files to ${CONFIG} var location
	mkdir -p "${HOME}/.config/home-backup"
	cp "backup-manager.sh" "${HOME}/.config/home-backup"
	cp "include-from.txt" "${HOME}/.config/home-backup"

	# Add env-variable based paths that change from system to system,
	# e.g. $HOME
	# These paths are conditional based on what system I am backing up
	# TODO: Put this config of paths somewhere else and load it! (JSON?)
	paths=()

	# Filter
	# Add any path (grep regex) to filter out when using '*' glob
	filters=()
	filters+=(".*ES.*themes.*")

	# Data
	paths+=("${HOME}/Emulation/saves")

	# Model 2 stuff is hard to setup, save!
	paths+=("${HOME}/Emulation/roms/model2/EMULATOR*")
	paths+=("${HOME}/Emulation/roms/model2/CFG")
	paths+=("${HOME}/Emulation/roms/model2/*meta*")
	paths+=("${HOME}/Emulation/roms/model2/*pat")
	paths+=("${HOME}/Emulation/roms/model2/*ps")
	paths+=("${HOME}/Emulation/roms/model2/*lua")
	paths+=("${HOME}/Emulation/bios/BIOS-ARCHIVES")

	# General configs to backup
	paths+=("${HOME}/ES-DE/*")

	# My general configs to save
	paths+=("${HOME}/.supermodel")
	paths+=("${HOME}/.bashrc")
	paths+=("${HOME}/.zshrc")

	for this_path in ${paths[@]};
	do
		skip=false
		# Skip path?
		for fpath in ${filters[@]};
		do
			if echo "${this_path}" | grep -qE "${fpath}"; then
				echo "[WARN] Skipping path '${this_path}' (filtered)"
				skip=true
			fi
		done
		if $skip; then
			continue
		fi

		echo "[INFO] Checking if path or file exists: '${this_path}'"
		if echo \'${this_path}\' | grep -q '*'; then 
			# Add glob
			regex=$(basename "${path}")
			base_path=$(dirname "${path}")
			echo "[INFO] Analyzing results of glob '${regex}' for path ${base_path} to include-from.txt"
			find "${base_path}" -name \""${regex}"\" -exec echo {} >> "${HOME}/.config/home-backup/include-from.txt" \;

		elif [[ -d "${this_path}" ]]; then 
			echo "[INFO] Adding directory '${this_path}' to include-from.txt"
			echo "${this_path}/**" >> "${HOME}/.config/home-backup/include-from.txt"

		elif [[ -f "${path}" ]]; then 
			echo "[INFO] Adding file '${this_path}' to include-from.txt"
			echo "${this_path}" >> "${HOME}/.config/home-backup/include-from.txt"

		fi
	done

}

rclone_stop_service(){
    systemctl --user stop home-backup.timer
    systemctl --user stop home-backup.service
}

rclone_start_service(){
    systemctl --user start home-backup.timer
}

function create_service() {
	echo "[INFO] Copying configs"
	cp "home-backup.service" "$HOME/.config/systemd/user/"
	cp "home-backup.timer" "$HOME/.config/systemd/user/"
	systemctl --user enable home-backup.service

	echo "[INFO] Enabling SaveBackup 15 minute timer service"
	systemctl --user enable home-backup.timer

	echo "[INFO] Starting Timer"
	rclone_start_service
}

main() {
	while :; do
		case $1 in
			--install|-i)
				INSTALL="true"
				;;

			--configure|-c)
				CONFIGURE="true"
				;;

			--backup|-b)
				BACKUP="true"
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
		configure
		create_service
		exit 0
	fi	

	if [[ ${CONFIGURE} == "true" ]]; then
		configure
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
		echo "[INFO] Running rclone to home-backup/${HOSTNAME}"
		cmd="/usr/bin/rclone copy --verbose --verbose -L --include-from ${HOME}/.config/home-backup/include-from.txt ${START_PATH} home-backup-gdrive:home-backup/${HOSTNAME} -P"
		echo "[INFO] Running cmd: ${cmd}"
		sleep 3
		eval "${cmd}" 2>&1 | tee "/tmp/rclone-job.log"

		if [ $? -eq 0 ]; then
			echo "[INFO] Cleanaing PID file $PIDFILE"
			rm $PIDFILE
		fi

		# Trim logs
		echo "[INFO] Trimming logs"
		find /tmp -name "${LOG_FILE}*" -mtime 14 -exec -delete \; 2>/dev/null
	fi
}

# Start and log
main "$@" 2>&1 | tee "${LOG_FILE}"
echo "[INFO] Log: ${LOG_FILE}"
echo "[INFO] clone operation log: /tmp/rclone-job.log"

