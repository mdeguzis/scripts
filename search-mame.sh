#!/bin/bash

# -------------------------------------------------------------------------------
# Author:     	Michael DeGuzis
# Git:	      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 	build-test-chroot.sh
# Script Ver: 	0.1.3
# Description:	Searches latest available mame.txt for game, returns file
#               name matches to look for in your list of ROMs.
#	
# -------------------------------------------------------------------------------

# set vars
scriptdir=$(pwd)
mametxt="$scriptdir/extra/MAME.txt"
gamearg="$1"

main()
{
  clear
  # obtain latest mame list
  # TODO
  
  # Calculate MD5sum of MAME.txt
  # Valid MD5sum hash: "7586e4ffecb86296d2492f704a91e00e MAME.txt"
  MD5sum_valid="7586e4ffecb86296d2492f704a91e00e  MAME.txt"
  MD5sum_check=$(md5sum MAME.txt)
  
  # check for MAME.txt in pwd, download if missing
  if [[ -f "MAME.txt" ]]; then
    # check MD5sum, if not "our" MAME.txt, backup and pull ours
    if [[ "$MD5sum_valid" != "$MD5sum_check"  ]]; then
      echo -e "MAME.txt appears corrupt, fetching...\n"
      sleep 1s
      wget -nv "https://github.com/ProfessorKaos64/scripts/blob/master/extra/MAME.txt"
    fi
  else
    echo -e "MAME.TXT Game file not found in currend directory. Fetching\n"
    sleep 1s
    wget -nv "https://github.com/ProfessorKaos64/scripts/blob/master/extra/MAME.txt"
  fi
  
  # Use listing I have from RetroRig-ES for now
  # mametxt="$scriptdir/extra/MAME.txt"
  
  # Search game list
  gameresults_title=$(grep -i $gamearg $mametxt | grep -i "Game: ")
  gameresults_file=$(grep -i $gamearg $mametxt | grep -i "Game Filename: ")
  
  # echo output
  echo -e "\nROM files that closely relate to the game title "
  echo -e "[${gamearg}]:\n"
  
  count=1

  grep -i $gamearg $mametxt | grep -i -E 'Game: |Game Filename: ' | while read -r game ; do
    echo -e "($count) $game"
    count=$((count+1))
  done
  
  exit
  
  # evaluate
  if [[ "$gameresults_title" == "" || "$gameresults_file" == "" ]]; then
    echo -e "Game title $gamearg not found...\n"
  else
    echo -e "$gameresults_file\n"
  fi
  
  # Format results
  #TODO
  
}

# Start main
main
