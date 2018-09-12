#!/bin/sh

TPM2TOOLS_TCTI=device:/dev/tpmrm0
TPM2TOOLS_TCTI_NAME=device
TPM2TOOLS_DEVICE_FILE=/dev/tpmrm0
MOUNTPOINT="$(mktemp -d /tmp/mnt.XXXXXXXX)"

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

disk_key=$(tpm2_unseal -Q -H 0x81010011 -L sha1:0,2,4,9,11,12,14)
if [ $? -gt 0 ]
then
    try_usb
else
    echo -n "$disk_key" | cryptsetup luksOpen --test-passphrase /dev/disk/by-uuid/UUID_ROOT_PARTITION
    if [ $? -gt 0 ]
    then
        try_usb
    else
        echo -n "$disk_key"
    fi
fi
