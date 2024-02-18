#!/usr/local/bin/bash

### Sync Opnsense blocklists with the existing ntopng blocklists
### Run: $0 to display the converted blocklist defitions
### Run: $0 -f to produce ntopng file for each blocklist (requires ntopng running with the standard folder setup, accessible)
### Run: $0 -[f]h to produce output with http link for each blacklist (requires also http server running, accessible)
### There are limitations, like type of filter is url, output category is malware (ntopng offers very little choice).
### The disadvantage is ntopng has to reprocess what firewall already did (but couldn't report to any meaningful GUI), and also re-fetch files periodically.
### Run http server:
###   python3 -m http.server --bind 127.0.0.1 --directory /var/db/aliastables/
### ..this will be accesible only internally, and as a bonus, will export Crowdsec filter (without need for their "blocklist server").
### Variables can be altered to change paths, or filters
input=/usr/local/etc/filter_tables.conf                            #firewall definition of filters e.g. "/usr/local/etc/filter_tables.conf"
input_http=/var/db/aliastables/                                    #firewall processed filters e.g. "/var/db/aliastables/"
output_file=/usr/local/share/ntopng/httpdocs/misc/lists/custom/    #ntopng custom blocklist folder e.g. "/usr/local/share/ntopng/httpdocs/misc/lists/custom/"
output_http=http://localhost:8000/                                 #http server location (add path if it's not running in $input_http folder) e.g. "http://localhost:8000/"
filter_included=''                                                 #filter names to include, leave empty for all e.g. "" or "blocklist"
filter_excluded='wan_vpn_'                                         #filter names to exclude, leave empty for none e.g. "" or "alias_"

[ "$1" == "--help" ] && grep -e "^### " $0 | sed "s/\$0/$(printf '%s\n' "$0" | sed 's:[\\/&]:\\&:g; $!s/$/\\/')/" | sed "s/### //" && exit 0
# Use xmllint to count tables
[ "$filter_excluded" == "" ] && filter_excluded="*"
tables=\<tabledef\>$(xmllint --xpath "/tabledef/table[type='urltable' and url!='' or type='external'][name!='' and contains(., '$filter_excluded')=false and contains(., '$filter_included')]" $input)\</tabledef\>
# Iterate through each table
for ((i=1; i <= $(xmllint --xpath "count(/tabledef/table)" - <<< $tables); i++)); do
  # Build XPath expression for current table
  table_xpath="/tabledef/table[$i]"
  # Extract relevant elements using xmllint
  name=$(xmllint --xpath "string($table_xpath/name)" - <<< $tables)
  url=$(xmllint --xpath "string($table_xpath/url)" - <<< $tables)
  interval=$(xmllint --xpath "string($table_xpath/ttl)" - <<< $tables)
  [ ! -z "${interval##*[!0-9.]*}" ] && interval=$(printf "%.${2:-0}f" $interval) || interval=86400
  category=malware #sadly only mining,malware,advertisement categories are hardcoded
  format=ip #vaste majority of blocklists will be with IP or IP/subset, hostname or enriched list would need extra logic

  # Handle multiple URLs
  if [ "$1" == "-h" -o "$1" == "-fh" ]; then
    url_file="$input_http$name.self.txt"
    if ! stat $url_file > /dev/null; then echo "Error: Input filter file $url_file does not exist"; continue; fi
    if [ $(stat -f %z $url_file) -le 0 ]; then echo "Warning: Input filter file $url_file is empty"; fi
    interval=3600 #since local updates are cheapier and we don't want too big gaps in overlapping schedule windows, and also intercept admin changes, we use the "minimum" (a hook would be better)
    url_array="$output_http$name.self.txt"
  else
    url_array=(${url// / })
  fi

  # Iterate through each URL
  c=1
  for url_item in "${url_array[@]}"; do
    [ ${#url_array[@]} -gt 1 ] && counter=$c || counter=
    # Construct the JSON object with the current URL
    json_object="{\"name\":\"$name$counter\",\"format\":\"$format\",\"enabled\":true,\"update_interval\":$interval,\"url\":\"$url_item\",\"category\":\"$category\"}"

    # Output the JSON object
    if [ "$1" == "-f" -o "$1" == "-fh" ]; then
      [ $i -eq 1 -a $c -eq 1 ] && echo "Writing filter files into $output_file folder."
      if [ -f $output_file$name$counter.list ] && [ $(cat $output_file$name$counter.list) == "$json_object" ]; then
        echo "Skipped $output_file$name$counter.list, nothing to update"
      else
        echo "$json_object" > "$output_file$name$counter.list" && echo "Updated $output_file$name$counter.list with $category $format list" || exit 2
        chmod o+r $output_file$name$counter.list || exit 3 #ntop GUI crashes without it, as the whole installation is root but processes not, and script might not add this attribute in action.d run
      fi
    else
      [ $i -eq 1 -a $c -eq 1 ] && echo "Use -f switch to place the files to the ntopng folder."
      echo "$json_object"
    fi
    c=$((c + 1))
  done
done
