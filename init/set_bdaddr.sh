#!/vendor/bin/sh
serial=$(/vendor/bin/sed -n 's/.*androidboot\.serialno=\([^ ]*\).*/\1/p' /proc/cmdline)
md5=$(echo -n "$serial" | /vendor/bin/md5sum)
exec /vendor/bin/hw/bdaddr $(echo "c0$md5" | /vendor/bin/cut -c1-12 | /vendor/bin/sed 's/../&:/g; s/:$//')
