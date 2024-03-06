#!/bin/bash

docker run \
    --env PS1="ADC(\#)[\d \T:\w]\\$ " \
    --interactive \
    --privileged \
    --rm \
    --tty \
    --volume "/tmp/target:/target" \
    "index.docker.io/library/archlinux:base-devel" /bin/bash
