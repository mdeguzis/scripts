#!/bin/bash

# Nextcloud All-in-One Installer Script
set -e

function usage {
  echo "Usage: $0 [-t|--type <client|server>]"
  exit 1
}

# Parse arguments
TYPE=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -t|--type)
      if [[ -n "$2" && ( "$2" == "client" || "$2" == "server" ) ]]; then
	TYPE="$2"
	shift 2
      else
	echo "Error: Invalid or missing argument for -t|--type. Expected 'client' or 'server'."
	usage
      fi
      ;;
    *)
      echo "Error: Unknown argument $1"
      usage
      ;;
  esac
done

if [[ -z "$TYPE" ]]; then
  echo "Error: Missing required argument -t|--type."
  usage
fi

if [[ "$TYPE" == "server" ]]; then	
  echo "Installing erew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Check for Podman (daemon-less, unlike Docker)
  if ! command -v podman &> /dev/null; then
    echo "Podman is not installed. Installing Podman..."
    brew install podman
    podman run --rm hello-world
  else
    echo "podman is already installed."
  fi

  # Pull the Nextcloud All-in-One Image
  echo "Pulling the Nextcloud All-in-One Docker image..."
  podman run \
	--init \
	--sig-proxy=false \
	--name nextcloud-aio-mastercontainer \
	--restart always \
	--publish 80:80 \
	--publish 8080:8080 \
	--publish 8443:8443 \
	--volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
	nextcloud/all-in-one:latest
else
  echo "Client type is not implemented yet."
  exit 1
fi

