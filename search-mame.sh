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
  
  # Use listing I have from RetroRig-ES for now
  mametxt="$scriptdir/extra/MAME.txt"
  
  # Search game list
  gameresults_file=$(grep -i $gamearg $mametxt | grep -i "Game Filename: ")
  gameresults_title=$(grep -i $gamearg $mametxt | grep -i "Game: ") 
  
  echo -n "$gameresults_title $gameresults_file"
  exit
  
  if [[ "$gameresults_title" == "" ]]; then
    # no game title found
    echo "" > /dev/null
  else
    gameresults_file=$(grep -i $gameresults_title $mametxt | grep -i 'Game Filename: ')
  fi
  

  # Format results
  #TODO
  
  # echo output
  echo -e "\nROM files that closely relate to the game title "
  echo -e "[${gamearg}]:\n"
  
  # evaluate
  if [[ "$gameresults_title" == "" || "$gameresults_file" == "" ]]; then
    echo -e "Game title $gamearg not found..."
  else
    echo -e "${gameresults_title}: ${gameresults_file}"
  fi

}

# Start main
main
