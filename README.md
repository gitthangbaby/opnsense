# opnsense+

Make Opnsense great again.

## Browsing blocklist hits

Issue: Firewall doesn't show blocked connections easily. There's a Live View which is short lived, or Plain View, which barely works and shows ugly plain information.

We can watch the file on CLI:
`alias filterlog='less +F /var/log/filter/latest.log'`
which is also hard to read.

If your IP rules is what your filters is based on, you will not like ZenArmor solution either. Let's hope the nonexistance of viewing blocks isn't a staight upsell. You can also try Maltrail plugin.

One solution is to let ntopng be the viewwer of the blocks. It's not efficient since it's double work, but better than nothing.

[sync_blocklists_to_ntopng.sh](sync_blocklists_to_ntopng.sh)
Will sync firewall blocklists with ntopng. Ntopng will immediatelly start using and marking your blocklists. The script can either parse the URL links and let ntopng fetch them with almost same frequency, or even better, it can directly read your processed blocklists from the filesystem if it's published on HTTP server:

Usage:

`sync_blocklists_to_ntopng.sh`
show what target JSON files look like

`sync_blocklists_to_ntopng.sh -f`
create target files

`sync_blocklists_to_ntopng.sh -h`
show what target JSON files pointing to HTTP look like

`sync_blocklists_to_ntopng.sh -fh`
create target files pointing to resolved blocklists published on HTTP

Note that there are some limitations. Ntopng will not display specificic frequencies. It will not offer enough of category names. It will be less effective parsing blocklists from the internnet (especially in non HTTP mode). We're focusing on IP lists. Ntopng can't even process IP list with remarks, or refer to local files, so I run a limited tiny HTTP server and this way we avoid double fetching of blocklists (but real time double marking stays, so what happens is ntopng has to go through your lists again, in delayed mode, and mark the blocks):
python3 -m http.server --bind 127.0.0.1 --directory /var/db/aliastables/

[actions_ntopng_plus.conf](actions_ntopng_plus.conf)
Schedule action in the cron GUI or run manually (`configctl ntopng_plus blocklistsync`)

Additionally, we want to choose what interfaces ntopng processes. This is a problem with GUI not able to select interfaces. Ntopng Community Edition has limit of 8. Likely, the limit will be crossed on many devices.
[49-ntopngfix](49-ntopngfix)
The startup script will define interfaces from that file. It will be valid until next installation _and_ reboot. Choose "None" in the GUI.

> [!TIP]
> The solution is ineffective due to second processing of the same blocklists, although delayed. Not a problem from CPU perspective as IP blocklists are way cheaper than inspection or even DNS blocklists.

## ZFS with snapshots and boot environments
Issue: Firewall is using ZFS without features. That's a total waste of space. Don't be surprised if your VM image will baloon, and all for nothing.

Solution: introduce regular snapshotting per hour and day, and also creation of boot environments for dual reason: have even more snapshots, and be able to restore system after installtion during boot.

[zfs_snapshot.sh](zfs_snapshot.sh) [zfs_cleanup.sh](zfs_cleanup.sh)

Usage:

`zfs_snapshot.sh min_space [dataset]`

`zfs_cleanup.sh min_space max_snapshots max_days_hourly max_days_daily max_be`

This will keep creating snapshots per parameters, respecting minimal disk space. It will also emergency clean up the earlies snapshots if the disk is running out of space.

[actions_zfs_plus.conf](actions_zfs_plus.conf)
Schedule action in the cron GUI or run manually (`configctl zfs_plus besnapshot 10000000000`)

> [!TIP]
> Calculate the expected snapshot usage yourself, and multiply by daily and hourly snapshots, to be able to fit all snapshots in the drive without hitting emergency cleanup. Some apps can radically increse the snapshot size (e.g. ntopng). Well, there's a fix for that too. You can rellocate ntopng data folder to NFS: `server:/mnt/shared /mnt/shared/ nfs rw,nolockd,retrycnt=1 0 0` in /etc/fstab and linking /mnt/shared/ntopng to /var/db/ntopng.

## Route mess on VPN

Issue: static router can't be added as hostnames. We need routes to prevent "IT" (the firewall, which is not filtered by default and doesn't use VPN in multi gateway config) accessing WAN. We need it also to get proper IP in ACME or DDNS process.

In RC or action hooks, you can slap some script:
`echo -e "\n$(date) Refreshing static routes..."
for host in freedns.afraid.org api.cloudflare.com staging.api.letsencrypt.org prod.api.letsencrypt.org cloudflare-dns.com 
    for ip in $(host -4t A $host | grep " has address " | cut -d' ' -f4); do
        case $host in
            freedns.afraid.org | api.cloudflare.com) iface=wg2;;
            staging.api.letsencrypt.org | prod.api.letsencrypt.org | cloudflare-dns.com) iface=wg3;;
            *) iface=wg1;;
        esac
        if [ "$iface" != "none" -a "$iface" != "" ]; then
            route add -inet $ip/32 -link -iface $iface && echo "Route of $host ($ip) to $iface added" || echo "Route of $host ($ip) to $iface not added"
        fi
    done
done`

> [!TIP]
> Choose interfaces based on where you want to redirect it. Choose DDNS redirect based on which VPN is your entry point. Add all hostnames firewall and all its apps can use, except perhaps NTP and boostrap DNS.

## Regular antivirus scan

Issue: like in many distros, antivirus exists, antivirus not able to run. 

Solution: schedule it, and report to email in case of issue.

[actions_clamavscan.conf](actions_clamavscan.conf)

Schedule action in the cron GUI or run manually (`configctl clamavscan reload`)

## Schedule anything

Issue: there's no custom command in the GUI scheduler. We want to run anything, no doubt.

Solution: new cron action to run any command under any user

[actions_run.conf](actions_run.conf) [run.sh](run.sh)

Usage: `run.sh [@user] [command [..]]`

Schedule action in the cron GUI or run manually (`configctl run @root rm -rf /var/db/ntopng`)

> [!TIP]
> First argument is can be optionally a username starting with "@". Default user is nobody.
