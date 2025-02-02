#!/bin/bash

set -e

cat<<-EOF

NOTE: This follows https://www.reddit.com/r/SteamDeck/comments/1i9ly7b/vice_city_nextgen/, allowing you
to use ENB. It does NOT remove any files. 

Known issues:

1. The fourth intro cutscene crashes the game. When the 3rd scene plays, mash ENTER on an attached keyboard.
   A controller will NOT work for this. You can also copy a save game to ~/Games/ and this script will
   pick it up and apply it for any new installs.


EOF
read -erp "Press ENTER to continue. CTRL+C to exit."

game_path=$(find ~/.local/share/Steam/steamapps/compatdata/ -name "GTA Vice City Nextgen Edition" -not -path "*Start Menu*" -type d)
echo "Using game path: ${game_path}"
sleep 3

echo -e "\nInstalling components via Protontrick (flapak)"
sleep 2
flatpak --user run com.github.Matoking.protontricks 3054562829 d3dcompiler_42
flatpak --user run com.github.Matoking.protontricks 3054562829 d3dcompiler_43
flatpak --user run com.github.Matoking.protontricks 3054562829 d3dcompiler_47
flatpak --user run com.github.Matoking.protontricks 3054562829 d3dx9_42
flatpak --user run com.github.Matoking.protontricks 3054562829 d3dx9_43

echo -e "\nOpening winecfg.exe. Please add d3d9 to overrides in the libraries tab..."
read -erp "Press ENTER to continue. CTRL+C to exit."
sleep 2
flatpak --user run com.github.Matoking.protontricks 3054562829 winecfg

echo -e "\nDONE!"
