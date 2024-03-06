#!/bin/bash

VOLUME_PATH="/tmp/target"
echo "[INFO] Creating Docker volume path ${VOLUME_PATH}"
mkdir -p "${VOLUME_PATH}"
chown -R "${USER}" "${VOLUME_PATH}"

echo "[INFO] Building Docker image"
docker build . \
	--build-arg HOST_USER=${USER} \
	--build-arg UID=$(id -u) \
	--build-arg GID=$(id -g) \
	--tag archlinux-dev
