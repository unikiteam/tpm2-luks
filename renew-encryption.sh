#!/bin/sh

PCR_FILE=$1
export TPM2TOOLS_TCTI=device:/dev/tpmrm0
export TPM2TOOLS_TCTI_NAME=device
export TPM2TOOLS_DEVICE_FILE=/dev/tpmrm0
DISK="/dev/disk/by-uuid/UUID_ROOT_PARTITION"
TMPDIR=$(mktemp -d)
TPM_SLOT="2"
umask 0077

dd if=/dev/urandom bs=1 count=32 | base64 | tr -d '\n' > "$TMPDIR/key"

#Create Policy
tpm2_createpolicy -Q -P -L sha1:0,2,4,9,11,12,14 -F "$PCR_FILE" -f "$TMPDIR/pcr.policy"
if [ $? -ne 0 ]
then
    rm -rf "$tmpdir"
    exit $?
fi

#Seal the key to the TPM and policy
tpm2_create -Q -g sha1 -G keyedhash -H 0x81010009 -u "$TMPDIR/sealedkey.pub" -r "$TMPDIR/sealedkey.priv" -A "fixedtpm|fixedparent|sensitivedataorigin|noda|adminwithpolicy" -L "$TMPDIR/pcr.policy" -I "$TMPDIR/key"
if [ $? -ne 0 ]
then
    rm -rf "$tmpdir"
    exit $?
fi

#Load the created object
tpm2_load -Q -H 0x81010009 -u "$TMPDIR/sealedkey.pub" -r "$TMPDIR/sealedkey.priv" -C "$TMPDIR/load.context"
if [ $? -ne 0 ]
then
    rm -rf "$tmpdir"
    exit $?
fi

#Remove the old key if present
tpm2_listpersistent | grep 0x81010011
if [ $? -eq 0 ] ; then
    tpm2_evictcontrol -A o -H 0x81010011
    if [ $? -ne 0 ]
    then
        rm -rf "$tmpdir"
        exit $?
    fi
fi

#Make the new key persistent
tpm2_evictcontrol -A o -c "$TMPDIR/load.context" -S 0x81010011
if [ $? -ne 0 ]
then
    rm -rf "$tmpdir"
    exit $?
fi

# Kill the existing key
echo "Removing old key..."
cryptsetup luksKillSlot "$DISK" "$TPM_SLOT" -d /keys/rootkey.bin

# Add the key to LUKS
echo "Adding key..."
cryptsetup luksAddKey "$DISK" -S "$TPM_SLOT" -d /keys/rootkey.bin "$TMPDIR/key"

# Clean up
rm -rf "$tmpdir"
