#!/bin/sh

/bin/systemctl stop tpm2-resourcemgr
PCR_FILE=$1
TOOLSDIR="/opt/tpmdisk"
DISK="/dev/disk/by-uuid/UUID_SDA3"
TPM_SLOT="2"
PCRS="0 2 4 9 11 12 14"
PCR_BITS="5A15"
tmpdir=$(mktemp -d)
umask 0077

# Make a new key
dd if=/dev/urandom bs=1 count=32 | base64 | tr -d '\n' > "$tmpdir/newkey.bin"

# Make text policy file
"$TOOLSDIR/policymakerpcr" -halg sha1 -bm $PCR_BITS -if "$PCR_FILE" -of "$tmpdir/pcr-policy.txt"

if [ $? -gt 0 ]
then
    >&2 echo "Make PCR policy failed!"
    rm -rf "$tmpdir"
    exit 1
fi

# Make binary policy file
"$TOOLSDIR/policymaker" -halg sha1 -if "$tmpdir/pcr-policy.txt" -of "$tmpdir/pcr-policy.bin"

if [ $? -gt 0 ]
then
    >&2 echo "Policy maker failed!"
    rm -rf "$tmpdir"
    exit 1
fi

# Seal the actual file
"$TOOLSDIR/create" -halg sha1 -nalg sha1 -hp 81000001 -bl -kt p -kt f -pol "$tmpdir/pcr-policy.bin" -if "$tmpdir/newkey.bin" -opr "/bk/sealedkey_priv.bin" -opu "/bk/sealedkey_pub.bin"

if [ $? -gt 0 ]
then
    >&2 echo "Seal to TPM failed!"
    rm -rf "$tmpdir"
    exit 1
fi

# Kill the existing key
echo "Removing old key..."
cryptsetup luksKillSlot "$DISK" "$TPM_SLOT" -d /keys/rootkey.bin

# Add the key to LUKS
echo "Adding key..."
cryptsetup luksAddKey "$DISK" -S "$TPM_SLOT" -d /keys/rootkey.bin "$tmpdir/newkey.bin"

/bin/systemctl start tpm2-resourcemgr

# Clean up
rm -rf "$tmpdir"
