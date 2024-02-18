#!/usr/bin/env sh
#Requires regular snapshots of zroot/ROOT/default, zroot/usr, zroot/var ended with @YYMMDDHHMM string (see timestamp variable)
#and regular boot environments called zroot/ROOT/be ended with YYMMDDHHMM string (see timestamp variable)
#to be run several times a day, or even after each snapshot hourly
#Parameters:
#$1 - min_space - minimal disk space reserved in bytes
#$2 - max_snapshots - maximal total number of snapshots per dataset, should be higher than max_days_daily + <interval>*max_days_hourly + max_be
#$3 - max_days_hourly - maximal days with hourly snapshots
#$4 - max_days_daily - maximal days with daily snapshots, should be higher than max_days_hourly
#$5 - max_be - maximal number of boot environments

    if [ "$1" == "" -o "$2" == "" -o "$3" == "" -o "$4" == "" -o "$5" == "" ]; then echo "Syntax: $0 min_space max_snapshots max_days_hourly max_days_daily max_be"; exit 0; fi

    echo -e "\n$(date) $0 start"
    min_space=$1; max_snapshots=$2; max_days_hourly=$3; max_days_daily=$4; max_be=$5; `#defaults: min_space=10000000000; max_snapshots=100; max_days_hourly=3; max_days_daily=20; max_be=8;`;
    timestamp="[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9]"
    timestamp_be="[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]-[0-2][0-9]:[0-5][0-9]:[0-5][0-9]-[0-9]"
    if [ $min_space -lt 0 -o $max_snapshots -gt 10000 -o $max_days_hourly -le 0 -o $max_days_daily -le 0 -o $max_days_hourly -gt $max_days_daily ]; then echo -e "\n$(date) $0 error - Parameters incorrect"; exit 2; fi;
    echo -e "Dataset used, available (target: $min_space B):\n$(zfs get -Hp -o value used,available zroot)\n"
    for i in $(zfs list -t snapshot -Hp -o name zroot/ROOT/default); do if [ $(expr "$i" : ".*@$timestamp$") != 0 ]; then first_day1=$(echo $i|cut -d'@' -f2); break; fi; done;
    for i in $(zfs list -t snapshot -Hp -o name zroot/usr);          do if [ $(expr "$i" : ".*@$timestamp$") != 0 ]; then first_day2=$(echo $i|cut -d'@' -f2); break; fi; done;
    for i in $(zfs list -t snapshot -Hp -o name zroot/var);          do if [ $(expr "$i" : ".*@$timestamp$") != 0 ]; then first_day3=$(echo $i|cut -d'@' -f2); break; fi; done;
    echo -e "Dataset snapshot count (target: $max_snapshots, up to $max_days_hourly days for hourly or $max_days_daily daily):\n" \
        "$(zfs get -Hp -o value snapshot_count zroot/ROOT/default) (Earliest snapshot: $first_day1)\n" \
        "$(zfs get -Hp -o value snapshot_count zroot/usr) (Earliest snapshot: $first_day2)\n" \
        "$(zfs get -Hp -o value snapshot_count zroot/var) (Earliest snapshot: $first_day3)\n";
    first_day=$(echo -e "$first_day1\n$first_day2\n$first_day3" | sort -rn | tail -1)
    count_be=0
    for i in $(zfs list -t snapshot -Hp -o name zroot/ROOT/default); do if [ $(expr "$i" : ".*@$timestamp_be$") != 0 ]; then [ -z $first_day_be ] && first_day_be=$(echo $i|cut -d'@' -f2); count_be=$(expr $count_be + 1); fi; done;
    echo -e "Boot environment snapshot count (target: $max_be):\n" \
        "$count_be (Earliest snapshot: $first_day_be)\n"

    echo -e "\nCleaning up hourly or daily snapshots in the past...";
    days_back=$max_days_hourly `#number of days with hourly snapshots`;
    first_day=$(printf %-.6s $first_day) `#first day with snapshots existing`;
    last_day_hourly=$(date -v "-${max_days_hourly}d" "+%y%m%d%H%M") `#last day of hourly snapshots`;
    last_day_daily=$(date -v "-${max_days_daily}d" "+%y%m%d%H%M") `#last day of daily snapshots`;
    day=$(date -v "-${max_days_hourly}d" "+%y%m%d") `#last day of hourly snapshots`;

    if [ $last_day_daily -gt $last_day_hourly ]; then echo -e "\n$(date) $0 error - Parameters incorrect"; exit 3; fi;
    count=0
    while [ $day -ge $first_day ]; do
        [ "$$day" != "$(date +%y%m%d)" ] && \
            for i in $(zfs list -t snapshot -Hp -o name zroot/ROOT/default zroot/usr zroot/var | grep -we "$timestamp"); do
        	if [ $(expr "$i" : ".*@${day}....$") != 0 ]; then
        	    time=$(echo $i | sed "s/.*@\($timestamp\)/\1/")
        	    if [ $(expr "$i" : ".*@${day}00..$") = 0 -a $time -le $last_day_hourly -o $time -le $last_day_daily ]; then
        		echo "Deleting $i"; sudo zfs destroy $i;
        	    fi;
        	fi;
    	    done;
        days_back=$(expr $days_back + 1);
        day=$(date -v "-${days_back}d" "+%y%m%d");
        count=$(expr $count + 1); if [ $count -gt 1000 ]; then echo -e "\n$(date) $0 error - Too long cycle"; exit 4; fi;
    done;

    echo -e "\nCleaning up boot environment snapshots in the past...";
    if [ $(bectl list -s | grep -we "zroot/ROOT/default@$timestamp_be" | wc -l) -ne $count_be ]; then echo -e "\n$(date) $0 error - Mismatch between boot environments and snapshots"; exit 6; fi;
    if [ $(bectl list -s | grep -we "zroot/ROOT/be$timestamp" | wc -l) -ne $count_be ]; then echo -e "\n$(date) $0 warning - Manually created boot environments exist and might be not needed"; fi;
    count=0
    while [ $(expr $count_be - $max_be) -gt $count ]; do
        for i in $(zfs list -Hp -o name); do
    	    if [ $(expr "$i" : "zroot/ROOT/be$timestamp$") != 0 ]; then
    		echo "Deleting $i"; sudo bectl destroy $i; count=$(expr $count + 1); if [ $count -gt 1000 ]; then echo -e "\n$(date) $0 error - Too long cycle"; exit 5; fi; break
    	    fi;
    	done;
    done

    echo -e "\nCleaning up snapshots if there are too many or disk is getting full...";
    count=0
    while [ $(zfs get -Hp -o value available zroot) -lt $min_space -o $(zfs get -Hp -o value snapshot_count zroot/ROOT/default) -gt $max_snapshots -o $(zfs get -Hp -o value snapshot_count zroot/usr) -gt $max_snapshots -o $(zfs get -Hp -o value snapshot_count zroot/var) -gt $max_snapshots ]; do
        for i in $(zfs list -t snapshot -Hp -o name zroot/ROOT/default); do if [ $(expr "$i" : ".*@$timestamp$") != 0 ]; then echo "Deleting $i"; sudo zfs destroy $i; break; fi; done;
        for i in $(zfs list -t snapshot -Hp -o name zroot/usr);          do if [ $(expr "$i" : ".*@$timestamp$") != 0 ]; then echo "Deleting $i"; sudo zfs destroy $i; break; fi; done;
        for i in $(zfs list -t snapshot -Hp -o name zroot/var);          do if [ $(expr "$i" : ".*@$timestamp$") != 0 ]; then echo "Deleting $i"; sudo zfs destroy $i; break; fi; done;
        sleep 0.1;
        count=$(expr $count + 1); if [ $count -gt 1000 ]; then echo -e "\n$(date) $0 error - Too long cycle"; exit 7; fi;
    done;
    sudo zfs set snapshot_limit=$max_snapshots zroot/ROOT/default;
    sudo zfs set snapshot_limit=$max_snapshots zroot/usr;
    sudo zfs set snapshot_limit=$max_snapshots zroot/var

    echo -e "\n$(date) $0 end"
