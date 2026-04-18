#!/bin/bash
# -------------------------------------------------------------------------------
# Author:       mike
# Script Name:  smb-recover.sh
# Description:  Recover files deleted from an SMB share via testdisk/photorec.
#               Attempts full directory structure recovery via testdisk first,
#               then falls back to photorec for raw file content recovery.
# Usage:        sudo smb-recover.sh [DEVICE] [OUTPUT_DIR]
#               sudo smb-recover.sh /dev/sda ~/recovered
#               sudo smb-recover.sh              # auto-detects by label prompt
# -------------------------------------------------------------------------------

set -e

# ---- colors ------------------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---- root check --------------------------------------------------------------
[[ "$EUID" -ne 0 ]] && error "Run as root: sudo $0"

# ---- deps --------------------------------------------------------------------
if ! command -v photorec &>/dev/null || ! command -v testdisk &>/dev/null; then
    warn "testdisk not found. Installing..."
    apt-get install -y testdisk
fi

# ---- device selection --------------------------------------------------------
DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
    echo ""
    info "Available block devices:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL | grep -v "^loop"
    echo ""
    read -rp "Enter device to recover from (e.g. /dev/sda): " DEVICE
fi

[[ ! -b "$DEVICE" ]] && error "Device '$DEVICE' not found or not a block device."

# Safety: refuse to run on a mounted device
if mount | grep -q "^$DEVICE"; then
    error "$DEVICE is currently mounted. Unmount it first to avoid overwriting deleted data."
fi

# Safety: refuse to run on the system root disk
ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null | head -1)
if [[ "/dev/$ROOT_DISK" == "$DEVICE" || "$ROOT_DISK" == "$DEVICE" ]]; then
    error "$DEVICE appears to be the system disk. Aborting."
fi

# ---- output directory --------------------------------------------------------
OUTPUT_DIR="${2:-$HOME/recovered}"
if [[ "$OUTPUT_DIR" == /dev/* || "$OUTPUT_DIR" == "$DEVICE"* ]]; then
    error "Output dir cannot be on the recovery device itself."
fi
mkdir -p "$OUTPUT_DIR"
info "Recovered files will be saved to: $OUTPUT_DIR"

# ---- summary -----------------------------------------------------------------
echo ""
echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}  SMB File Recovery${NC}"
echo -e "${YELLOW}======================================${NC}"
info "Device:     $DEVICE"
info "Output dir: $OUTPUT_DIR"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$DEVICE" 2>/dev/null || true
echo ""

# ---- step 1: testdisk (directory structure + filenames) ----------------------
echo ""
info "STEP 1: testdisk — attempts to recover original folder structure and filenames."
info "In testdisk: Proceed > Advanced > select partition > Undelete"
info "Press any key to launch testdisk, or Ctrl+C to skip to photorec..."
read -rn1

testdisk "$DEVICE" || warn "testdisk exited with errors — continuing to photorec."

# ---- step 2: photorec (raw file content fallback) ----------------------------
echo ""
read -rp "Run photorec now for raw file content recovery? [Y/n]: " RUN_PHOTOREC
RUN_PHOTOREC="${RUN_PHOTOREC:-Y}"

if [[ "$RUN_PHOTOREC" =~ ^[Yy]$ ]]; then
    info "STEP 2: photorec — recovers file content without original filenames."
    info "In photorec: select partition > Other (for exFAT/FAT/NTFS) > navigate to output dir > C"
    info "Press any key to launch photorec..."
    read -rn1

    photorec "$DEVICE"

    echo ""
    info "photorec complete. Check $OUTPUT_DIR for recovered files."
    info "Files are named generically (e.g. f0001234.mkv) — use 'ffprobe' to inspect video metadata."
fi

# ---- done --------------------------------------------------------------------
echo ""
info "Recovery session complete."
info "Output: $OUTPUT_DIR"
echo ""
warn "Next steps if filenames are missing:"
echo "  1. Check MKV titles:  ffprobe FILE.mkv 2>&1 | grep -i title"
echo "  2. Query Plex DB on server via ADB for original filenames"
echo "  3. Sort by file size/duration to manually identify content"
