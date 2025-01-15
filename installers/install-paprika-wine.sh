#!/bin/bash

# Function to display error messages and exit
function error_exit {
    echo "[INFO] Error: $1" >&2
    exit 1
}

echo -e "\n-------------------------------------------------------"
echo "[INFO] Add architecture for Wine"
echo -e "-------------------------------------------------------\n"

# TODO - add other OS package manager types here...
sudo dpkg --add-architecture i386 || error_exit "Failed to add i386 architecture"
echo "[INFO] i386 architecture added successfully."

sudo apt update || error_exit "Failed to update package list"
echo "[INFO] Package list updated successfully."

echo -e "\n-------------------------------------------------------"
echo "[INFO] Install Wine"
echo -e "-------------------------------------------------------\n"
sudo apt install --install-recommends wine-stable -y || error_exit "Failed to install Wine"
echo "[INFO] Wine installed successfully."

echo -e "\n-------------------------------------------------------"
echo "[INFO] Download and prepare Winetricks"
echo -e "-------------------------------------------------------\n"
read -erp "Press ENTER"
wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks || error_exit "Failed to download Winetricks"
chmod +x winetricks || error_exit "Failed to make Winetricks executable"
echo "[INFO] Winetricks downloaded and prepared successfully."

echo -e "\n-------------------------------------------------------"
echo -e "[INFO] Run winecfg to set Windows version to Windows 10"
echo -e "-------------------------------------------------------\n"
read -erp "Press ENTER"
winecfg || error_exit "Failed to configure Wine"
echo "[INFO] Wine configured successfully. Please ensure Windows version is set to Windows 10."

echo -e "\n-------------------------------------------------------"
echo "[INFO] Install dependencies using Winetricks"
echo -e "-------------------------------------------------------\n"

echo -e "\n------------------------"
echo -e "winetricks: allfonts"
echo -e "------------------------\n"
read -erp "Press ENTER"
./winetricks allfonts || error_exit "Failed to install allfonts"
echo "[INFO] Allfonts installed successfully."

echo -e "\n------------------------"
echo -e "winetricks: dotnet472"
echo -e "------------------------\n"
read -erp "Press ENTER"
#./winetricks dotnet472 || error_exit "Failed to install .NET 4.7.2"
./winetricks dotnet472
echo "[INFO] .NET 4.7.2 installed successfully."

echo -e "\n------------------------"
echo -e "winetricks: fontsmooth-rgb"
echo -e "------------------------\n"
read -erp "Press ENTER"
./winetricks fontsmooth-rgb || error_exit "Failed to enable fontsmooth-rgb"
echo "[INFO] Fontsmoothing enabled successfully."

echo -e "\n-------------------------------------------------------"
echo "[INFO] Install Paprika"
echo -e "-------------------------------------------------------\n"
read -erp "Press ENTER"
if [ ! -f ~/PaprikaSetup.msi ]; then
    error_exit "PaprikaSetup.msi not found in home directory. Please download it before running this script."
fi

wine msiexec /i ~/PaprikaSetup.msi || error_exit "Failed to install Paprika"
echo -e "\n[INFO] Paprika installed successfully."
read -erp "Press ENTER"

echo -e "\n-------------------------------------------------------"
echo -e "[INFO] = Configure Wine to resolve Redshift conflict"
echo -e "-------------------------------------------------------\n"
read -erp "Press ENTER"
wine regedit || error_exit "Failed to open Wine registry editor"
echo "[INFO] Please navigate to HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver, create the key if it doesn't exist, and set UseXVidMode to N."
echo "[INFO] Redshift conflict workaround applied."
read -erp "Press ENTER"

# Clean up
echo -e "\n-------------------------------------------------------"
echo "[INFO] Finishing up"
echo -e "-------------------------------------------------------\n"
read -erp "Press ENTER"
rm -f ./winetricks || error_exit "Failed to remove Winetricks script"
echo "[INFO] Winetricks script removed successfully."
read -erp "Press ENTER"

# Create a desktop entry for Paprika
DESKTOP_FILE="$HOME/.local/share/applications/paprika.desktop"
mkdir -p $(dirname "$DESKTOP_FILE") || error_exit "Failed to create applications directory"
cat > "$DESKTOP_FILE" << EOL
[Desktop Entry]
Name=Paprika Recipe Manager
Exec=wine "c:\\Program Files\\Paprika Recipe Manager 3\\Paprika.exe"
Type=Application
StartupNotify=true
Path=$HOME
Icon=applications-wine
EOL

if [ -f "$DESKTOP_FILE" ]; then
    echo "[INFO] Desktop entry created successfully at $DESKTOP_FILE"
else
    error_exit "Failed to create desktop entry"
fi

echo "[INFO] Installation completed! You can run Paprika with:"
echo "[INFO] wine \"c:\\Program Files\\Paprika Recipe Manager 3\\Paprika.exe\""

