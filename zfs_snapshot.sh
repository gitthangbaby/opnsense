#!/usr/bin/env sh
#Creates regular snapshots of custom or default zroot/ROOT/default, zroot/usr, zroot/var ended with @YYMMDDHHMM string (see timestamp variable)
#or regular boot environments called zroot/ROOT/be ended with YYMMDDHHMM string (see timestamp variable)
#to be run hourly. The other script will clean them up based on hourly, daily requirement, and disk space
#Parameters:
#$1 - min_space - minimal disk space reserved in bytes
#$2 - dataset - dataset to be snapped ("", "@default": default datasets, "@be": boot environment)

if [ "$1" == "" ]; then echo "Syntax: $0 min_space [dataset|@default|@be]"; exit 0; fi

echo -e "\n$(date) $0 start"

dataset=$2; `#defaults: min_space=10000000000; dataset="zroot/ROOT/default@$snaptime zroot/usr@$snaptime zroot/var@$snaptime"`;
if [ ! -z "${1##*[!0-9]*}" ]; then
    min_space=$1
else
    echo -e "\n$(date) $0 error - Parameters incorrect"
    exit 2
fi
snaptime=$(date +%y%m%d%H%M)
if [ "$dataset" == "" -o "$dataset" == "@default" ]; then
    dataset="zroot/ROOT/default@$snaptime zroot/usr@$snaptime zroot/var@$snaptime"
elif [ "$dataset" == "@be" ]; then
    dataset=be$snaptime
else
    dataset=$dataset@$snaptime
fi

if [ $(zfs get -Hp -o value available zroot) -ge $min_space ]; then
    if [ "$dataset" == "be$snaptime" ]; then
	echo "Adding boot environment $dataset"
	sudo bectl create $dataset
    else
        echo "Adding snapshot $dataset"
        sudo zfs snapshot $dataset
    fi
else
    echo -e "\n$(date) $0 error - Not enough disk space"
    exit 3
fi
echo -e "\n$(date) $0 end"
