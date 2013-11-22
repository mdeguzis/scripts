#!/bin/sh
#
#Script to record JB Live shows
#
cd /home/$USER/Videos
ffmpeg -i rtsp://videocdn-us.geocdn.scaleengine.net/jblive/live/jblive.stream -b 900k -vcodec copy -r 60 -t 02:00:00 -y LAS+`date +%Y%m%d`.avi
cd /home/$USER

