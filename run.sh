user=admin
if [ "$(echo $1 | cut -b 1)" == "@" ]; then
    user=$(echo $1 | cut -b 2-16)
    shift
fi
echo "$(date) Executing '$@' as $user" >> $0.log
sec=$(date +%s)
sudo -n -u $user $@ >> $0.log
ex=$?
sec=$(expr $(date +%s) - $sec)
echo "$(date) Finished in $sec sec and $ex code" >> $0.log
exit $ex
