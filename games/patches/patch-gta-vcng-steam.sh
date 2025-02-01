#!/bin/bash

set -e

game_path=$(find ~/.local/share/Steam/steamapps/compatdata/ -name "GTA Vice City Nextgen Edition" -not -path "*Start Menu*" -type d)
echo "Using game path: ${game_path}"
sleep 3

rm -fv "${game_path}/d3d9.dll"

cp -v "${game_path}/data_launch/enb/del_enb/gtaRainRender.xml" "${game_path}/common/data/"
cp -v "${game_path}/data_launch/enb/del_enb/gtaStormRender.xml" "${game_path}/common/data/"
cp -v "${game_path}/data_launch/enb/del_enb/visualSettings.dat" "${game_path}/common/data/"

cp -v "${game_path}/data_launch/enb/del_enb/timecyc.dat" "${game_path}/pc/data/"
cp -v "${game_path}/data_launch/enb/del_enb/timecyclemodifiers.dat" "${game_path}/pc/data/"
cp -v "${game_path}/data_launch/enb/del_enb/timecyclemodifiers2.dat" "${game_path}/pc/data/"
cp -v "${game_path}/data_launch/enb/del_enb/timecyclemodifiers3.dat" "${game_path}/pc/data/"
cp -v "${game_path}/data_launch/enb/del_enb/timecyclemodifiers4.dat" "${game_path}/pc/data/"


cp -v "${game_path}/data_launch/enb/del_enb/lights_occluders.wtd" "${game_path}/pc/textures/"
cp -v "${game_path}/data_launch/enb/del_enb/skydome.wtd" "${game_path}/pc/textures/"
cp -v "${game_path}/data_launch/enb/del_enb/stipple.wtd" "${game_path}/pc/textures/"
cp -v "${game_path}/data_launch/enb/del_enb/stipple.wtd" "${game_path}/pc/textures/"

echo -e "\nDONE!"
