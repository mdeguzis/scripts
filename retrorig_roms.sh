#!/bin/bash
#==============================================================================
#title           :retrorig_roms.sh
#description     :This script will sync between my two rom directories. It is
#		  important that SSH keys are setup on the host machine and
#		  transferred beforehand. See the following link:
#	          http://goo.gl/mfz52L
#author		 :PK
#date            :20140916
#version         :0.1    
#usage		 :used in cronjob / 'crontab -e'
#notes           :Needs tweaking.
#==============================================================================

###############################
# rsync info on logging
###############################

# A line starting with >f+++++++++ indicates a new file was created on the destination, 
# followed by the path.

# A line starting with cd+++++++++ indicates a new directory (folder) was created on 
# the destination, followed by the path.

# A line starting with >f.st...... indicates a file was updated because of size and 
# time stamp difference, followed by the path.

# A line starting with .d..t...... indicates a directory (folder) was updated because 
# of time stamp difference, followed by the path.

# *deleting indicates the file (or folder) was deleted from the destination, followed 
# by the path.

################################
# rsync commands and code
################################
# Note: Make sure you specify the private key you generated
# with the '-rsh=' flag (seen below). Otherwise, the cron session
# Will have no idea of the ssh agent you normally would have in a
# bash session.

export now=$(date +"%Y-%m-%d-%S") && rsync -aP --exclude="z_RetroRig_Test_ROMs" \
--exclude="*.nfo" --exclude="tools" --exclude="temp" --exclude="Dreamcast" --delete \
--log-file=/home/mikeyd/user_logs/retrorig_trnsfr_log$now.log \
--rsh='ssh -p 22 -i /home/mikeyd/.ssh/id_rsa' \
/mnt/server_media_x/ROMs/ mikeyd@retrorig:/home/mikeyd/RetroRig/ROMs

################################
# prune logs
################################
# Here we want to keep keep logs that are at least 2 days old
# since I am running this job every every hour of the day in
# my cron job list

find /home/mikeyd/user_logs/ -type f -name "*.log" -mtime 2 -exec rm -f {} \;
