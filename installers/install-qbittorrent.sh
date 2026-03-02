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
echo "Default Password: See log with 'sudo systemctl status qbittorrent-nox --no-pager"
echo "-------------------------------------------------------"
