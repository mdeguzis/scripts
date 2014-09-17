#!/bin/bash

################################
# rsync commands and code
################################

export now=$(date +"%Y-%m-%d-%S") && rsync -aP --exclude="zRetroRig_Test_ROMs" 
--exclude="tools" --exclude="temp" --exclude="Dreamcast" --delete 
--log-file=/home/mikeyd/user_logs/retrorig_trnsfr_log$now.txt /mnt/server_media_x/ROMs 
mikeyd@retrorig:/home/mikeyd/RetroRig/ROMs

################################
# prune logs
################################

rm -f $(ls -1t /home/mikeyd/user_logs/ | tail -n +11)
