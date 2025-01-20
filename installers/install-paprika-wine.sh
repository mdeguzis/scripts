# /bin/bash

# Script to install Paprika using Wine with a dedicated prefix

set -e

APP_NAME="Paprika"
WINE_PREFIX="$HOME/.wine-paprika"
WINE_VERSION="stable"  # Change to "staging" or "devel" if needed
INSTALLER_URL="https://www.paprikaapp.com/downloads/windows/latest/PaprikaSetup.msi"
INSTALLER_PATH="$HOME/Downloads/Paprika3-Setup.exe"

echo "Installing $APP_NAME with a dedicated Wine prefix at $WINE_PREFIX."

# Step 1: Ensure dependencies are installed
echo "Checking dependencies..."
if ! command -v wine &>/dev/null; then
    echo "Wine is not installed. Installing Wine..."
    sudo apt update && sudo apt install -y wine wine64 winetricks
fi
if ! command -v winetricks &>/dev/null; then
    echo "Winetricks is not installed. Installing Winetricks..."
    sudo apt update && sudo apt install -y winetricks
fi

# Step 2: Create a dedicated Wine prefix
echo "Creating dedicated Wine prefix at $WINE_PREFIX..."
WINEARCH="win32"  # Ensure 32-bit prefix for compatibility
export WINEPREFIX="$WINE_PREFIX"

if [ ! -d "$WINE_PREFIX" ]; then
    wineboot --init
fi

# Step 3: Install necessary Wine components
echo "Installing required Wine components..."
winetricks -q dotnet48 corefonts

# Step 4: Download the installer
if [ ! -f "$INSTALLER_PATH" ]; then
    echo "Downloading Paprika installer..."
    wget -O "$INSTALLER_PATH" "$INSTALLER_URL"
else
    echo "Paprika installer already downloaded at $INSTALLER_PATH."
fi

# Step 5: Run the installer
echo "Running Paprika installer: ${INSTALLER}"
wine msiexec /i "$INSTALLER_PATH"

# Step 6: Create a desktop shortcut
DESKTOP_ENTRY="$HOME/.local/share/applications/$APP_NAME.desktop"
echo "Creating desktop shortcut at $DESKTOP_ENTRY..."
cat <<EOF >"$DESKTOP_ENTRY"
[Desktop Entry]
Name=Paprika
Exec=env WINEPREFIX=${HOME}/.wine-paprika wine start /unix "${HOME}/.wine-paprika/drive_c/Program Files/Paprika Recipe Manager 3/Paprika.exe"
Type=Application
Categories=Utility;
EOF

chmod +x "$DESKTOP_ENTRY"

# Step 7: Finish up
echo "Installation complete! You can launch $APP_NAME from your application menu."

