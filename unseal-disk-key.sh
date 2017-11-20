#!/bin/sh

TOOLSDIR="/opt/tpmdisk"

mount -t ext4 /dev/disk/by-uuid/UUID_SDA2 /tmp
disk_key=$("$TOOLSDIR/unseal-from-pcrs.sh" "/tmp/sealedkey_priv.bin" "/tmp/sealedkey_pub.bin" /dev/stdout)
if [ $? -ne 0 ]
then
    exec /lib/cryptsetup/askpass "Enter disk recovery key: "
else
    echo -n "$disk_key"
fi
