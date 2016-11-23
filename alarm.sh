#!/bin/bash

__script_version="1.0"

#Default Values

human_time="tomorrow 5:30"
media_url="./Music/allthesmallthings.mp3"

function gradual() {
    amixer -c 0 set Master 10% > /dev/null
    current_volume=$(amixer -c 0 get Master | egrep -o "[0-9]+%")
    current_volume=${current_volume//%}

    while [[ current_volume -lt 100 ]]
    do
        sleep 5
        current_volume=$(amixer -c 0 set Master 10%+ | egrep -o "[0-9]+%")
        current_volume=${current_volume//%}
    done
}

function fallback () {
    got_input=142

    until [ $got_input -eq 0]
    do
        frequency=$(shuf -i 200-600 -n 1)
        speaker-test -f $frequency -t sine -l 1 > /dev/null &
        disown $!

        duration=$(echo "$(shuf -i 5-25 -n 1) * 0.1" | bc)
        read -t $duration
        
        got_input=$?

        pkill -9 --ns $$ speaker-test
    done        
}        

function usage() {
    echo "Usage: 0 [options] [--]
    
    Options:
    -h|help     Display this message
    -v|version  Display script version
    -m|media    The audio url, to be played by mplayer
    -t|time     The human readable time and date for the alarm"
}

while getopts ":hvm:t:" opt
do 
    case $opt in 

        h|help      )   usage; exit 0   ;;

        v|version   )   echo "$0 -- vversion $__script__version"; exit 0    ;;

        m|media     )   media_url=$OPTARG   ;;

        t|time      )   human_time=$OPTARG  ;;

        *   )   echo -e "\n Option does not exits : $OPTARG\n"
                usage; exit 1   ;;

    esac
done
shift $(($OPTIND-1))

echo $human_time
unix_time=$(date +%s -d "$human_time")
seconds=$(($unix_time - $(date +%s)))
echo $seconds

if [ $? -ne 0 ]; then
    echo "meh"
    exit 1
fi

hours_minutes="$(($seconds / 3600)) hours and $((($seconds / 60) % 60)) minutes"

read -p "Set alarm for $hours_minutes from now? [y/n] " go

if [ "$go" == n ]; then
    echo "bleh"
    exit 0
fi

sudo rtcwake -m mem -t $unix_time > /dev/null
sleep 30

saved_volume=$(amixer -c 0 get Master | egrep -o "[0-9]+%")

gradual &
mplayer -noconsolecontrols -really-quiet -msglevel all=-1 -nolirc "$media_url" > /dev/null &

got_input=142

while true; do
    if read -t 1; then
        got_input=$?
        pkill --ns $$ mplayer > /dev/null
        break 
    elif ! pgrep --ns $$ mplayer > /dev/null; then
        break
    fi
done


if [ $got_input -ne 0 ]
then
    gradual &
    fallback
fi

amixer -c 0 set Master $saved_volume > /dev/null

echo "Remember to do homework and Dont forget to pray!"