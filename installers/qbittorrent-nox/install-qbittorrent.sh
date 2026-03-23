#!/bin/bash

# 1. Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install qBittorrent-nox
echo "Installing qBittorrent-nox..."
sudo apt install qbittorrent-nox -y

# 3. Create a dedicated system user
echo "Creating qbittorrent-nox system user..."
sudo useradd -r -m qbittorrent-nox
# Add your current user to the qbittorrent group for file access
sudo usermod -a -G qbittorrent-nox $USER

# 4. Create the systemd service file
echo "Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/qbittorrent-nox.service
[Unit]
Description=qBittorrent-nox service
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=exec
User=qbittorrent-nox
Group=qbittorrent-nox
ExecStart=/usr/bin/qbittorrent-nox
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 5. Start and enable the service
echo "Starting qBittorrent-nox..."
sudo systemctl daemon-reload
sudo systemctl enable qbittorrent-nox
sudo systemctl start qbittorrent-nox

echo "-------------------------------------------------------"
echo "Setup complete! Access the Web UI at:"
echo "http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "Default Username: admin"
echo "Default Password: See log with 'sudo systemctl status qbittorrent-nox --no-pager'"
echo "-------------------------------------------------------"

# -------------------------------------------------------
# Optional: Samba share for completed downloads
# -------------------------------------------------------
echo ""
read -p "Set up completed downloads sync to a Samba share? [y/N] " setup_samba
if [[ "$setup_samba" =~ ^[Yy]$ ]]; then

    read -p "Samba share (e.g. //192.168.1.128/samsung): " SMB_SHARE
    read -p "Mount point (e.g. /mnt/nvidia-shield): " SMB_MOUNT
    read -p "Completed downloads path on share (e.g. /mnt/nvidia-shield/media/downloads): " SAVE_PATH
    read -p "Samba credentials file (e.g. /home/$USER/.smbcredentials): " SMB_CREDS

    INCOMPLETE_DIR=/home/qbittorrent-nox/Downloads/incomplete

    # Create mount point and incomplete dir
    sudo mkdir -p "$SMB_MOUNT"
    sudo mkdir -p "$INCOMPLETE_DIR"
    sudo chown -R qbittorrent-nox:qbittorrent-nox /home/qbittorrent-nox/Downloads

    # Add qbittorrent-nox to the current user's group so it can write to the share
    sudo usermod -aG "$USER" qbittorrent-nox

    # Add fstab entry with group-writable permissions (if not already present)
    if ! grep -q "$SMB_SHARE" /etc/fstab; then
        echo "" | sudo tee -a /etc/fstab
        echo "# SMB share for qBittorrent completed downloads" | sudo tee -a /etc/fstab
        echo "$SMB_SHARE $SMB_MOUNT  cifs  credentials=$SMB_CREDS,uid=$(id -u $USER),gid=$(id -g $USER),file_mode=0775,dir_mode=0775,nofail  0  0" | sudo tee -a /etc/fstab
        sudo mount "$SMB_MOUNT"
    else
        echo "fstab entry for $SMB_SHARE already exists — ensure file_mode=0775,dir_mode=0775 is set."
    fi

    # Write qBittorrent config with temp path (local) and save path (share)
    # NOTE: Interface settings below fix a libtorrent 2.0.x ARM64 bug — see README
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -1)
    IFACE_IP=$(ip addr show "$IFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)

    sudo mkdir -p /home/qbittorrent-nox/.config/qBittorrent
    cat <<CONF | sudo tee /home/qbittorrent-nox/.config/qBittorrent/qBittorrent.conf
[Application]
FileLogger\Age=1
FileLogger\AgeType=1
FileLogger\Backup=true
FileLogger\DeleteOld=true
FileLogger\Enabled=true
FileLogger\MaxSizeBytes=66560
FileLogger\Path=/home/qbittorrent-nox/.local/share/qBittorrent/logs

[BitTorrent]
Session\DefaultSavePath=${SAVE_PATH}
Session\ExcludedFileNames=
Session\Interface=${IFACE}
Session\InterfaceAddress=${IFACE_IP}
Session\Port=7272
Session\QueueingSystemEnabled=false
Session\TempPath=${INCOMPLETE_DIR}
Session\TempPathEnabled=true

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=8

[Network]
Cookies=@Invalid()
PortForwardingEnabled=false

[Preferences]
WebUI\AuthSubnetWhitelist=@Invalid()
CONF

    sudo chown qbittorrent-nox:qbittorrent-nox /home/qbittorrent-nox/.config/qBittorrent/qBittorrent.conf

    sudo systemctl restart qbittorrent-nox

    echo ""
    echo "Samba sync configured:"
    echo "  Incomplete (in-progress): $INCOMPLETE_DIR"
    echo "  Completed downloads:      $SAVE_PATH"
    echo ""
    echo "Files download locally and are moved to the share only after completion."
fi
