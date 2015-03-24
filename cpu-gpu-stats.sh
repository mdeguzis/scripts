#!/bin/bash

clear

# Check for packages
#	if ! which lm-sensors > /dev/null; then
	if [[ -z $(type -P sensors) || -z $(type -P nvidia-smi) ]]; then
		echo ""
		echo "#####################################################"
		echo "Pre-req checks"	
		echo "#####################################################"
		echo "Did not find 1 or more of the packages: lm-sensors, or nvidia-smi"
		echo "Attempting to install these now.(Must have Debian Repos added)"
		echo ""
		sleep 3s
		# Update system first
		sudo apt-get update
		# fetch needed pkgs
		sudo apt-get -t wheezy install lm-sensors
		sudo apt-get install nvidia-smi
		if [ $? == '0' ]; then
			echo "Successfully installed 'lm-sensors/nvidia-smi'"
			sleep 3s
		else
			echo "Could not install 'lm-sensors/nvidia-smi. Exiting..."
			sleep 3s
			exit 1
		fi
	else
		echo "Found packages 'lm-sensors/nvidia-smi'."
		sleep 1s
	fi

clear
# Start Loop

while :
do
	clear
	echo "###########################################################"
	echo "Monitoring CPU and GPU temps"
	echo "###########################################################"
	echo "Press [CTRL+C] to stop.."
	echo ""

#############
#CPU
#############

# With Cores
sensors | grep -E '(Core|Physical)'

#############
#GPU
#############
echo ""
nvidia-smi -a | grep -E '(Name|Current Temp)'

# let stat's idel for a bit
sleep 2s

done
