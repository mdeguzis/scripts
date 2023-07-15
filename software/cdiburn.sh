#!/bin/sh
CDIIMG="$1"
cdirip "${CDIIMG}" -cdrecord
COUNTER="0"
MORE=true
while $MORE
        do
        COUNTER=`expr $COUNTER + 1`
        NUMBER=`printf %02u $COUNTER`
        ISOFILE=tdata${NUMBER}.iso
        WAVFILE=taudio${NUMBER}.wav
        if [ -f $WAVFILE ]; then
                cdrecord dev=/dev/cdrom speed=4 -multi -audio $WAVFILE && rm $WAVFILE
        elif [ -f $ISOFILE ]; then
                cdrecord dev=/dev/cdrom speed=4 -multi -xa $ISOFILE && rm $ISOFILE
        else
        MORE=false
        fi
done
eject
