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

################################
# rsync commands and code
################################
# Note: Make sure you specify the private key you generated
# with the '-rsh=' flag (seen below). Otherwise, the cron session
# Will have no idea of the ssh agent you normally would have in a
# bash session.

export now=$(date +"%Y-%m-%d-%S") && rsync -aP --exclude="z_RetroRig_Test_ROMs" \
--exclude="*.nfo" --exclude="tools" --exclude="temp" --exclude="Dreamcast" --delete \
--log-file=/home/mikeyd/user_logs/retrorig_trnsfr_log$now.txt \
--rsh='ssh -p 22 -i /home/mikeyd/.ssh/retrorig' \
/mnt/server_media_x/ROMs/ mikeyd@retrorig:/home/mikeyd/RetroRig/ROMs/

################################
# prune logs
################################

rm -f $(ls -1t /home/mikeyd/user_logs/ | tail -n +11)
