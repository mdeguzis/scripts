#!/bin/bash

set -e

cat<<-EOF

NOTE: This follows https://www.reddit.com/r/SteamDeck/comments/1i9ly7b/vice_city_nextgen/, allowing you
to use ENB. It does NOT remove any files. 

Known issues:

1. The fourth intro cutscene crashes the game. When the 3rd scene plays, mash ENTER on an attached keyboard.
   A controller will NOT work for this. You can also copy a save game to ~/Games/gta-vice-city-nextgen/savegames/ 
   and this script will pick it up and apply it for any new installs.


EOF

game_path=$(find ~/.local/share/Steam/steamapps/compatdata/ -name "GTA Vice City Nextgen Edition" -not -path "*Start Menu*" -type d)
game_id=$(echo "${game_path}" | awk -F'compatdata/' '{print $2}' | sed "s|/.*||")
echo "Using game path: '${game_path}'"
echo "Using Steam game ID: '${game_id}'"

read -erp "Press ENTER to continue. CTRL+C to exit."

echo -e "\nInstalling components via Protontrick (flapak)"
sleep 2
flatpak --user run com.github.Matoking.protontricks ${game_id} d3dcompiler_42
flatpak --user run com.github.Matoking.protontricks ${game_id} d3dcompiler_43
flatpak --user run com.github.Matoking.protontricks ${game_id} d3dcompiler_47
flatpak --user run com.github.Matoking.protontricks ${game_id} d3dx9_42
flatpak --user run com.github.Matoking.protontricks ${game_id} d3dx9_43

echo -e "\nOpening winecfg.exe. Please add d3d9 to overrides in the libraries tab..."
read -erp "Press ENTER to continue. CTRL+C to exit."
sleep 2
flatpak --user run com.github.Matoking.protontricks ${game_id} winecfg

echo -e "\nAdding any saves from ~/Games/gta-vice-city-nextgen/savegames/
cp -r "~/Games/gta-vice-city-nextgen/savegames/" "${HOME}/.local/share/Steam/steamapps/compatdata/${game_id}/pfx/drive_c/users/steamuser/Documents/Rockstar Games/GTA VC/savegames/"

echo -e "\nDONE!"
