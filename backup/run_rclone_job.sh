#!/bin/bash
PIDFILE="/tmp/rclone.pid"

function finish {
  echo "Script terminating. Exit code $?"
}

trap finish EXIT

if [ -z "$savesPath" ] || [ -z "$rclone_provider" ]; then
    echo "You need to setup your cloudprovider first."
    exit
fi

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  ps -p "$PID" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Process already running"
    exit 1
  else
    ## Process not found assume not running
    echo $$ > "$PIDFILE"
    if [ $? -ne 0 ]; then
      echo "Could not create PID file"
      exit 1
    fi
  fi
else
  echo $$ > "$PIDFILE"
  if [ $? -ne 0 ]; then
    echo "Could not create PID file"
    exit 1
  fi
fi

"/usr/bin/rclone" copy --verbose --verbose -L "$savesPath" "$rclone_provider":Emudeck/saves -P > "$toolsPath/rclone/rclone_job.log"
echo "Log: $toolsPath/rclone/rclone_job.log"

