#!/bin/bash

# -------------------------------------------------------------------------------
# Author:     	Michael DeGuzis
# Git:	      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 	build-test-chroot.sh
# Script Ver: 	0.1.1
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
  gameresults=(grep -i $gamearg $mametxt)
  
  # Format results
  #TODO
  
  # echo output
  echo -e "\nMatches that closely relate to the game title ${gamearg}:\n"
  
  # evaluate
  if [[ "$gameresults" == "" ]]; then
    echo -e "\nGame title $gamearg not found...\n"
  else
    echo -e "\n$gameresults"
  fi

}

# Start main
main
