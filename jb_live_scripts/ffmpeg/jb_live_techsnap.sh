#!/bin/sh
#
#Script to record JB Live shows
#
cd $HOME/Videos
ffmpeg -f rtsp -rtsp_transport tcp -i rtsp://videocdn-us.geocdn.scaleengine.net/jblive/live/jblive.stream -strict -2 -vcodec copy -t 02:00:00 -y techsnap_`date +%Y%m%d`.avi
cd $HOME

