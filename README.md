# opnsense+

Make Opnsense great again.


Issue: Firewall doesn't show blocked connections easily. There's a Live View which is short lived, or Plain View, which barely works and shows ugly plain information.

We can watch the file on CLI:
alias filterlog='less +F /var/log/filter/latest.log'
which is also hard to read.

If your IP rules is what your filters is based on, you will not like ZenArmor solution either. Let's hope the nonexistance of viewing blocks isn't a staight upsell. You can also try Maltrail plugin.

One solution is to let ntopng be the viewwer of the blocks. It's not efficient since it's double work, but better than nothing.

║*sync_blocklists_to_ntopng.sh
Will sync firewall blocklists with ntopng. Ntopng will immediatelly start using and marking your blocklists. The script can either parse the URL links and let ntopng fetch them with almost same frequency, or even better, it can directly read your processed blocklists from the filesystem if it's published on HTTP server:

sync_blocklists_to_ntopng.sh

show what target JSON files look like
sync_blocklists_to_ntopng.sh -f
create target files
sync_blocklists_to_ntopng.sh -h
show what target JSON files pointing to HTTP look like
sync_blocklists_to_ntopng.sh -fh
create target files pointing to resolved blocklists published on HTTP

Note that there are some limitations. Ntopng will not display specificic frequencies. It will not offer enough of category names. It will be less effective parsing blocklists from the internnet (especially in non HTTP mode). We're focusing on IP lists. Ntopng can't even process IP list with remarks, or refer to local files, so I run a limited tiny HTTP server and this way we avoid double fetching of blocklists (but real time double marking stays, so what happens is ntopng has to go through your lists again, in delayed mode, and mark the blocks):
python3 -m http.server --bind 127.0.0.1 --directory /var/db/aliastables/

║*actions_ntopng_plus.conf
Cron action to schedule in GUI or run manually (configctl ntopng_plus blocklistsync)


Additionally, we want to choose what interfaces ntopng processes. This is a problem with GUI not able to select interfaces. Ntopng Community Edition has limit of 8. Likely, the limit will be crossed on many device.
║*49-ntopngfix
The startup script will define interfaces. Choose "None" in the GUI.
