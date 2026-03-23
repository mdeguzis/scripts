# qBittorrent-nox on Raspberry Pi

Headless qBittorrent seedbox setup for Raspberry Pi (tested on Pi 5, Raspberry Pi OS Bookworm, ARM64).

Based on: https://www.gsvd.dev/blog/create-a-seedbox-on-raspberry-pi-using-the-latest-version-of-qbittorrent

## Files

| File | Description |
|------|-------------|
| `install-qbittorrent.sh` | Initial install script |
| `qBittorrent.conf` | Config backup (deploy to `/home/qbittorrent-nox/.config/qBittorrent/`) |
| `qbittorrent-nox.service` | systemd service file (deploy to `/etc/systemd/system/`) |

## Install

```bash
bash install-qbittorrent.sh
```

After install, deploy the fixed config (see bug fix below):

```bash
sudo cp qBittorrent.conf /home/qbittorrent-nox/.config/qBittorrent/qBittorrent.conf
sudo chown qbittorrent-nox:qbittorrent-nox /home/qbittorrent-nox/.config/qBittorrent/qBittorrent.conf
sudo systemctl restart qbittorrent-nox
```

## Access

- WebUI: `http://<pi-ip>:8080`
- Default user: `admin`
- Initial password: check `sudo systemctl status qbittorrent-nox` on first run

## Configuration

- BitTorrent port: **7272** (TCP + UDP) — forward this on your router to the Pi's IP
- WebUI port: **8080**
- UPnP/NAT-PMP: disabled (use manual port forwarding)

## Download Paths

Downloads use two locations to protect in-progress files from Samba share interruptions:

| Stage | Path |
|-------|------|
| In progress | `/home/qbittorrent-nox/Downloads/incomplete` (local) |
| Completed | `/mnt/nvidia-shield/media/downloads` (Samba share) |

qBittorrent moves files to the save path automatically on completion — no extra service needed.

### Samba share permissions

The CIFS mount must use `file_mode=0775,dir_mode=0775` and `qbittorrent-nox` must be in the owner's group so it can write completed downloads to the share.

`/etc/fstab`:
```
//192.168.1.128/samsung /mnt/nvidia-shield  cifs  credentials=/home/mikeyd/.smbcredentials,uid=1000,gid=1000,file_mode=0775,dir_mode=0775,nofail  0  0
```

Add `qbittorrent-nox` to the `mikeyd` group:
```bash
sudo usermod -aG mikeyd qbittorrent-nox
```

The install script handles all of this when you answer **y** to the Samba prompt.

---

## Bug Fix: Magnet Links Stuck on "Downloading Metadata"

### Symptom

Magnet links added to qBittorrent hang indefinitely at "Downloading metadata" and never progress.

### Root Cause

**libtorrent-rasterbar 2.0.11** (the version in Debian Bookworm backports) has a bug on ARM64/Raspberry Pi where it explicitly binds the BitTorrent listen socket to the loopback interface (`lo`) via `SO_BINDTODEVICE "lo"`, even when configured to listen on `0.0.0.0`.

Confirmed via strace:
```
setsockopt(12, SOL_SOCKET, SO_BINDTODEVICE, "lo\0", 3) = 0
bind(12, {sa_family=AF_INET, sin_port=htons(7272), sin_addr=inet_addr("127.0.0.1")}, 16) = 0
```

The qBittorrent log reports:
```
Trying to listen on the following list of IP addresses: "0.0.0.0:7272,[::]:7272"
Successfully listening on IP. IP: "127.0.0.1". Port: "TCP/7272"   ← loopback only!
Successfully listening on IP. IP: "127.0.0.1". Port: "UTP/7272"
```

Because **both TCP and UDP (DHT) sockets** are bound to loopback only (`127.0.0.1:7272`), DHT packets cannot leave the machine to reach peers on the internet — so metadata for magnet links is never downloaded.

This is not a timing/race condition: the bug reproduces even when the network is fully up, and even running as root with a clean config.

### Fix

Explicitly set the interface and IP in `/home/qbittorrent-nox/.config/qBittorrent/qBittorrent.conf` under `[BitTorrent]`:

```ini
[BitTorrent]
Session\Interface=wlan0
Session\InterfaceAddress=192.168.1.121
```

Replace `wlan0` and `192.168.1.121` with your actual interface and IP. With these set, libtorrent binds correctly:

```
Successfully listening on IP. IP: "192.168.1.121". Port: "TCP/7272"
Successfully listening on IP. IP: "192.168.1.121". Port: "UTP/7272"
```

### Important: Static IP

Because `Session\InterfaceAddress` is a hardcoded IP, if your Pi's DHCP lease changes qBittorrent will fail to bind. Set a **static DHCP reservation** on your router for the Pi's MAC address, or assign a static IP on the Pi.

Pi MAC address (wlan0): `2c:cf:67:df:b2:a8`

### Router Port Forwarding

Forward port **7272 TCP+UDP** to the Pi's IP for incoming peer connections:

| Protocol | External Port | Internal IP | Internal Port |
|----------|--------------|-------------|---------------|
| TCP | 7272 | 192.168.1.121 | 7272 |
| UDP | 7272 | 192.168.1.121 | 7272 |
