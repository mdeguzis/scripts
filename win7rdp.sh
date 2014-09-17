#!/bin/sh

SERVER=mikeyd-PC-win7

/usr/bin/rdesktop -g 1366x768 \
-a 16 \
-u mikeyd \
-d WORKSTATION \
$SERVER
