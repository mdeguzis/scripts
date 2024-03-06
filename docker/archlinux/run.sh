#!/bin/bash

docker run \
    --env PS1="ADC(\#)[\d \T:\w]\\$ " \
    --interactive \
    --tty \
	--privileged \
    --rm \
	--user ${USER} \
	--volume "/tmp/target:/home/${USER}" \
    "archlinux-dev"

# Remove any junk files
rm -rf "/tmp/target/Applications"
