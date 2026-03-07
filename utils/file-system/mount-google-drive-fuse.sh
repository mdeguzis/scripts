#!/bin/bash

# Exit script on any error
set -e

# Defaults
REMOTE_NAME="google-drive"
MOUNT_POINT="$HOME/google-drive"
VFS_CACHE_MODE="writes"
SKIP_INSTALL=false
UNMOUNT=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Mount Google Drive locally using rclone and FUSE.

OPTIONS:
  -r, --remote NAME         rclone remote name to use (default: google-drive)
  -m, --mount-point PATH    local directory to mount into (default: ~/google-drive)
  -c, --vfs-cache-mode MODE rclone vfs-cache-mode: off|minimal|writes|full
                            (default: writes)
  -u, --unmount             unmount the Google Drive mount point and exit
  -s, --skip-install        skip apt install of rclone/fuse packages
  -h, --help                show this help message and exit

EXAMPLES:
  $(basename "$0")
      Install deps, configure if needed, and mount using defaults.

  $(basename "$0") -r gdrive -m ~/google-drive
      Mount using a custom remote name and mount point.

  $(basename "$0") -c full
      Mount with full vfs caching (better performance, more disk use).

  $(basename "$0") -u
      Unmount the default mount point.

  $(basename "$0") -u -m ~/GoogleDrive
      Unmount a custom mount point.

NOTES:
  On first run, rclone will open a browser to authenticate with Google.
  You can optionally supply your own OAuth2 client_id and client_secret
  from the Google Cloud Console during rclone config for a private app
  registration. Otherwise rclone's built-in credentials are used.

  To run rclone config manually:
    rclone config

  To view mounted drives:
    rclone listremotes

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--remote)        REMOTE_NAME="$2";    shift 2 ;;
        -m|--mount-point)   MOUNT_POINT="$2";    shift 2 ;;
        -c|--vfs-cache-mode) VFS_CACHE_MODE="$2"; shift 2 ;;
        -u|--unmount)       UNMOUNT=true;         shift   ;;
        -s|--skip-install)  SKIP_INSTALL=true;    shift   ;;
        -h|--help)          usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Unmount and exit
if "$UNMOUNT"; then
    if mountpoint -q "$MOUNT_POINT"; then
        echo "Unmounting $MOUNT_POINT..."
        fusermount -u "$MOUNT_POINT"
        echo "Unmounted successfully."
    else
        echo "Nothing mounted at $MOUNT_POINT."
    fi
    exit 0
fi

# Install dependencies
if ! "$SKIP_INSTALL"; then
    echo "Updating package lists..."
    sudo apt update
    echo "Installing required packages (rclone, fuse3)..."
    sudo apt install -y rclone fuse3
fi

# Configure rclone remote if not present
if rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    echo "Rclone remote '${REMOTE_NAME}' already configured."
else
    echo "Configuring rclone for Google Drive (remote: ${REMOTE_NAME})..."
    rclone config create "$REMOTE_NAME" drive
    echo "Rclone configuration completed."
fi

# Create mount point if needed
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point at $MOUNT_POINT..."
    mkdir -p "$MOUNT_POINT"
fi

# Mount
echo "Mounting ${REMOTE_NAME}: -> $MOUNT_POINT (vfs-cache-mode=${VFS_CACHE_MODE})..."
rclone mount "${REMOTE_NAME}:" "$MOUNT_POINT" \
    --vfs-cache-mode "$VFS_CACHE_MODE" \
    --daemon

# Verify
if mountpoint -q "$MOUNT_POINT"; then
    echo "Google Drive successfully mounted at $MOUNT_POINT"
    echo "To unmount: $(basename "$0") -u -m $MOUNT_POINT"
else
    echo "Failed to mount Google Drive."
    exit 1
fi

