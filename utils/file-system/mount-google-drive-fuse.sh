#!/bin/bash

# Exit script on any error
set -e

# Define variables
REMOTE_NAME="google-drive"
MOUNT_POINT="$HOME/gdrive"

echo "Updating package lists..."
sudo apt update

# 'fuse' may be invalid here
# sudo apt install -y rclone 
echo "Installing required packages (rclone and fuse)..."
sudo apt install -y rclone

# Check if rclone is already configured
if rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    echo "Rclone remote '$REMOTE_NAME' already exists."
else
    echo "Configuring rclone for Google Drive..."
    rclone config create $REMOTE_NAME drive
    echo "Rclone configuration completed."
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point at $MOUNT_POINT..."
    mkdir -p "$MOUNT_POINT"
fi

# Mount Google Drive
echo "Mounting Google Drive to $MOUNT_POINT..."
rclone mount $REMOTE_NAME: $MOUNT_POINT --daemon

# Verify the mount
if mountpoint -q "$MOUNT_POINT"; then
    echo "Google Drive successfully mounted at $MOUNT_POINT. -la 
else
    echo "Failed to mount Google Drive."
    exit 1
fi

echo "All done!"

