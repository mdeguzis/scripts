#!/bin/bash

docker run \
    --env PS1="ADC(\#)[\d \T:\w]\\$ " \
    --interactive \
    --rm \
	--user "${USER}" \
    --tty \
    --volume "/tmp/target:/target" \
    "archlinux-dev" \
	/bin/bash
