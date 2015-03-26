#!/bin/bash

# -----------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/scripts
# Scipt Name:	steamos-stats.sh
# Script Ver:	0.4.3
# Description:	Monitors various stats easily over an SSH connetion to
#		gauge performance and temperature loads on steamos.
# Usage:	./steamos-stats.sh
# Warning:	You MUST have the Debian repos added properly for 
#		Installation of the pre-requisite packages.
# TODO:		Add AMD GPU support
# ------------------------------------------------------------------------


clear
####################################################################
# Check for packages
####################################################################

	# FPS + more binds from VaporOS 2
	# For bindings, see: /etc/actkbd-steamos-controller.conf
	if [ ! -d "/usr/share/doc/vaporos-binds-xbox360" ]; then
		cd ~/Downloads
		wget https://github.com/sharkwouter/steamos-installer/blob/master/pool/main/v/vaporos-binds-xbox360/vaporos-binds-xbox360_1.0_all.deb
		sudo dpkg -i vaporos-binds-xbox360_1.0_all.deb
		cd
		if [ $? == '0' ]; then
			echo "Successfully installed 'vaporos-binds-xbox360'"
			sleep 3s
		else
			echo "Could not install 'vaporos-binds-xbox360'. Exiting..."
			sleep 3s
			exit 1
		fi
	else
		echo "Found package 'vaporos-binds-xbox360'."
		sleep 1s
	fi 

	# Temperature detection

	if [[ -z $(type -P sensors) || -z $(type -P nvidia-smi) || -z $(type -P sar) || -z $(type -P free) ]]; then
		echo ""
		echo "#####################################################"
		echo "Pre-req checks"
		echo "#####################################################"
		echo "Did not find 1 or more of the packages: lm-sensors, or" 
		echo "nvidia-smi, sar, free,or ssh"
		echo "Attempting to install these now.(Must have Debian Repos added)"
		echo ""
		sleep 3s
	
		# Update system first
		sudo apt-get update
		# fetch needed pkgs
		sudo apt-get -t wheezy install lm-sensors sysstat -y
		sudo apt-get install nvidia-smi openssh-server -y
		# detect sensors automatically
		sudo sensors-detect --auto

		if [ $? == '0' ]; then
			echo "Successfully installed pre-requisite packages"
			sleep 3s
		else
			echo "Could not install pre-requisite packages. Exiting..."
			sleep 3s
			exit 1
		fi
	else
		echo "Found packages 'lm-sensors/nvidia-smi/sar/free/ssh'."
		sleep 1s
	fi

clear

####################################################################
# voglperf testing
####################################################################
# Currently assumes hard location path of /home/desktop/voglperf
# Full AppID game list: http://steamdb.info/linux/
# Currently, still easier to use Shark's VaporOS package, which adds
# easy gamepad toggles for an FPS overlay

# sudo -u steam /home/desktop/voglperf/bin/voglperfrun64

####################################################################
# Start Loop
####################################################################
while :
do

	########################################
	# Set VARS
	########################################
	CPU=$(less /proc/cpuinfo | grep -m 1 "model name" | cut -c 14-70)
	CPU_TEMPS=$(sensors | grep -E '(Core|Physical)')
	CPU_LOAD=$(iostat | cut -f 2 | grep -A 1 "avg-cpu")
	
	MEM_LOAD=$(free -m | grep -E '(total|Mem|Swap)' |  cut -c 1-7,13-18,23-29,34-40,43-51,53-62,65-73)

	GPU=$(nvidia-smi -a | grep -E 'Name' | cut -c 39-100)
	GPU_DRIVER=$(nvidia-smi -a | grep -E 'Driver Version' | cut -c 39-100)
	GPU_TEMP=$(nvidia-smi -a | grep -E 'Current Temp' | cut -c 39-100)
	GPU_FAN=$(nvidia-smi -a | grep -E 'Fan Speed' | cut -c 39-100)

	clear
	echo "###########################################################"
	echo "Monitoring CPU and GPU statistics"
	echo "###########################################################"
	echo "Press [CTRL+C] to stop.."

	########################################
	# GPU Stats
	########################################
	
	echo ""
	echo "###########################################################"
	echo "GPU Stats"
	echo "###########################################################"
	echo "GPU Name: $GPU"
	echo "GPU Temp: $GPU_TEMP"
	echo "GPU Fan Speed: $GPU_FAN"

	########################################
	# CPU Stats
	########################################
	
	# With Cores
	echo ""
	echo "###########################################################"
	echo "CPU Stats"
	echo "###########################################################"
	echo "CPU Name: $CPU"
	echo ""
	echo "CPU Temp:"
	echo "$CPU_TEMPS"
	echo ""
	echo "CPU Utilization:"
	echo "$CPU_LOAD"
	
	########################################
	# MEMORY Stats
	########################################
	echo ""
	echo "###########################################################"
	echo "Memory Stats"
	echo "###########################################################"
	echo "$MEM_LOAD"
	
	# let stat's idel for a bit
	sleep 2s

done
