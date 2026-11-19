#!/vendor/bin/sh
serial=$(/vendor/bin/sed -n 's/.*androidboot\.serialno=\([^ ]*\).*/\1/p' /proc/cmdline)
addr=02$(echo -n "$serial" | /vendor/bin/md5sum | /vendor/bin/cut -c13-22 | /vendor/bin/sed 's/../:&/g')
i=0
while [ $i -lt 600 ]; do
    if [ -e /sys/class/net/wlan0 ]; then
        exec /vendor/bin/ifconfig wlan0 hw ether $addr
    fi
    /vendor/bin/sleep 0.1
    i=$((i + 1))
done
exit 1
