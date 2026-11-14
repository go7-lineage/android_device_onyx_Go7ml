#!/vendor/bin/sh
# First-boot aid: the kernel log to the logdump partition (stock's, 64 MiB) every 10 s for 10 min.
# Read it from EDL: edl r logdump logdump.bin; strings logdump.bin | sed -n '/^=== go7ml/,/^=== END/p'
i=0
while [ $i -lt 60 ]; do
    { echo "=== go7ml logdump $i, uptime $(cut -d' ' -f1 /proc/uptime)"; dmesg; echo "=== END"; } \
        > /dev/block/by-name/logdump
    sleep 10
    i=$((i + 1))
done
