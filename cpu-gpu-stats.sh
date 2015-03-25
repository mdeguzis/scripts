#!/bin/bash

clear

# Set vars
CPU=$(less /proc/cpuinfo | grep -m 1 "model name" | cut -c 14-70)
CPU_TEMPS=$(sensors | grep -E '(Core|Physical)')

GPU=$(nvidia-smi -a | grep -E 'Name' | cut -c 39-100)
GPU_DRIVER=$(nvidia-smi -a | grep -E 'Driver Version' | cut -c 39-100)
GPU_TEMP=$(nvidia-smi -a | grep -E 'Current Temp' | cut -c 39-100)
GPU_FAN=$(nvidia-smi -a | grep -E 'Fan Speed' | cut -c 39-100)

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
echo ""
echo "CPU Name: $CPU"
echo "CPU Temp:"
echo "$CPU_TEMPS"


#############
#GPU
#############
echo ""
echo "GPU Name: $GPU"
echo "GPU Temp: $GPU_TEMP"
echo "GPU Fan Speed: $GPU_FAN"

# let stat's idel for a bit
sleep 2s

done
