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
  
  # obtain latest mame list
  # TODO
  
  # check for MAME.txt in pwd, download if missing
  if [[ -f "MAME.txt" ]]
    # MAME.TXT found
    echo "" > /dev/null
  else
    wget "https://github.com/ProfessorKaos64/scripts/blob/master/extra/MAME.txt"
  fi
  
  # Use listing I have from RetroRig-ES for now
  # mametxt="$scriptdir/extra/MAME.txt"
  
  # Search game list
  gameresults_title=$(grep -i $gamearg $mametxt | grep -i "Game: ")
  gameresults_file=$(grep -i $gamearg $mametxt | grep -i "Game Filename: ")
  
  # echo output
  echo -e "\nROM files that closely relate to the game title "
  echo -e "[${gamearg}]:\n"
  
  # evaluate
  if [[ "$gameresults_title" == "" || "$gameresults_file" == "" ]]; then
    echo -e "Game title $gamearg not found...\n"
  else
    echo -e "$gameresults_file\n"
  fi
  
  # Format results
  #TODO
  
  # cleanup
  rm -f "MAME.txt"

}

# Start main
main
