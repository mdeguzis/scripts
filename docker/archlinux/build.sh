#!/bin/bash

echo "[INFO] Building Docker image"
docker build . \
	--build-arg HOST_USER="${USER}" \
	--tag archlinux-dev
