#!/bin/bash

# -------------------------------------------------------------------------------
# Author:     	Michael DeGuzis
# Git:	      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 	search-mame.sh
# Usage:	./search-mame
# Script Ver: 	0.1.3
# Description:	Searches latest available mame.txt for game, returns file
#               name matches to look for in your list of ROMs.
#	
# -------------------------------------------------------------------------------

# set vars
scriptdir=$(pwd)
mametxt="MAME.txt"
# capture all args
gamearg="$*"

main()
{
	clear
	# obtain latest mame list
	# TODO

	# ask for game? 
	#read -r -p "Enter game to search: " input
	#gamearg="$input"

	# Calculate MD5sum of MAME.txt
	# Valid MD5sum hash: "7586e4ffecb86296d2492f704a91e00e MAME.txt"
	MD5sum_valid="3514d9687eb495ad44e22a7b29454201  MAME.txt"
	MD5sum_check=$(md5sum MAME.txt 2> /dev/null)

	# check for MAME.txt in pwd, download if missing
	if [[ -f "MAME.txt" ]]; then
	
	# check MD5sum, if not "our" MAME.txt, backup and pull ours
	
		if [[ "$MD5sum_valid" != "$MD5sum_check"  ]]; then
			echo -e "MAME.txt appears corrupt, fetching...\n"
			sleep 1s
			wget -nv "https://raw.githubusercontent.com/ProfessorKaos64/scripts/master/extra/MAME.txt"
		fi
	else
		echo -e "MAME.TXT Game file not found in currend directory. Fetching\n"
		sleep 1s
		wget -nv "https://raw.githubusercontent.com/ProfessorKaos64/scripts/master/extra/MAME.txt"
	fi

	# Use listing I have from RetroRig-ES for now
	# mametxt="$scriptdir/extra/MAME.txt"

	# Search game list
	gameresults_title=$(grep -i "$gamearg" $mametxt | grep -i "Game: ")
	gameresults_file=$(grep -i "$gamearg" $mametxt | grep -i "Game Filename: ")

	# echo output
	echo -e "ROM files that closely relate to the game title "
	echo -e "["$gamearg"]:\n"

	# evaluate
	if [[ "$gameresults_title" == "" ]]; then
		echo -e "Game title "$gamearg" not found...\n"
	else
		grep -i -B 1 -A 7 "$gameresults_title" "$mametxt" | while read -r game ; do
			#echo $game 			
			result=$(grep -i -E "Game: |Game Filename: ")
			echo -e "$result\n"

		done

	fi


	# Format results
	#TODO
  	
}

# Start main
main
