#!/bin/bash

# Nextcloud All-in-One Installer Script
# Uses podman for a daemon-less approach
set -e

function usage {
    echo "Usage: $0 [-t|--type <client|server>]"
    exit 1
}

# Parse arguments
TYPE=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
    -t | --type)
        if [[ -n "$2" && ("$2" == "client" || "$2" == "server") ]]; then
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
    if ! command -v brew &>/dev/null; then
        echo "Installing brew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Check for Podman (daemon-less, unlike Docker)
    if ! command -v podman &>/dev/null; then
        echo "Podman is not installed. Installing Podman..."
        brew install podman
        podman run --rm hello-world
    else
        echo "podman is already installed."
    fi

    # Pull the Nextcloud All-in-One Image
    # Use Non-Privileged Ports
    echo "Pulling/running the Nextcloud All-in-One Docker image..."
    podman run \
        --detach \
        --name nextcloud-server \
        --volume ~/nextcloud-server:/var/www/html \
        --replace \
        -p 8080:80 \
        nextcloud

else
    echo "Client type is not implemented yet."
    exit 1
fi
