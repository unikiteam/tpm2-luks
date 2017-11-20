#!/bin/sh

TOOLSDIR="/opt/tpmdisk"
DISK="/dev/disk/by-uuid/UUID_SDA3"
TPM_SLOT="2"

tmpdir=$(mktemp -d)
umask 0077

# Make a new key
dd if=/dev/urandom of="$tmpdir/newkey.bin" bs=1 count=32

# Kill the existing key
echo "Removing old key..."
cryptsetup luksKillSlot "$DISK" "$TPM_SLOT" -d /keys/rootkey.bin

# Seal the new key to the TPM
echo "Sealing key to TPM..."
"$TOOLSDIR/seal-to-pcrs.sh" "$tmpdir/newkey.bin" "/boot/sealedkey_priv.bin" "/boot/sealedkey_pub.bin"

# Add the key to LUKS
echo "Adding key..."
cryptsetup luksAddKey "$DISK" -S "$TPM_SLOT" -d /keys/rootkey.bin "$tmpdir/newkey.bin"

# Clean up
rm -rf "$tmpdir"
