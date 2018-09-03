#!/bin/sh

TOOLSDIR="/opt/tpmdisk"
MOUNTPOINT="$(mktemp -d /tmp/mnt.XXXXXXXX)"

mount -t ext4 /dev/disk/by-uuid/UUID_KEYS_PARTITION "$MOUNTPOINT"

try_default() {
    echo -n "DEFAULT_KEY" | cryptsetup luksOpen --test-passphrase /dev/disk/by-uuid/UUID_ROOT_PARTITION
    if [ $? -gt 0 ]; then
        exec /lib/cryptsetup/askpass "Enter disk recovery key: "
    else
        echo -n "DEFAULT_KEY"
    fi
}

try_usb() {
    sleep 20
    KEY=""
    for disk in $(ls /dev/disk/by-id/*usb*); do
        MOUNTPOINT="$(mktemp -d /tmp/mnt.XXXXXXXX)"
        mount -t auto "$(readlink -f $disk)" "$MOUNTPOINT"
        if [ $? -eq 0 ]
        then
            ls "$MOUNTPOINT/key" > /dev/null && cat "$MOUNTPOINT/key" | cryptsetup luksOpen --test-passphrase /dev/disk/by-uuid/UUID_ROOT_PARTITION
            if [ $? -eq 0 ]; then KEY=$(cat "$MOUNTPOINT/key") && break; fi
        fi
    done
    cleanup
    if [ -z "$KEY" ]; then 
        try_default
    else
        echo -n "$KEY"
    fi
}

cleanup() {
    umount /tmp/*
    rm -rf /tmp/*
}

if [ $? -gt 0 ]
then
    try_usb
else
    disk_key=$("$TOOLSDIR/unseal-from-pcrs.sh" "$MOUNTPOINT/sealedkey_priv.bin" "$MOUNTPOINT/sealedkey_pub.bin" /dev/stdout)
    if [ $? -gt 0 ]
    then
        try_usb
    else
        echo -n "$disk_key" | cryptsetup luksOpen --test-passphrase /dev/disk/by-uuid/UUID_ROOT_PARTITION
        if [ $? -gt 0 ]
        then
            try_usb
        else
            cleanup
            echo -n "$disk_key"
        fi
    fi
fi
