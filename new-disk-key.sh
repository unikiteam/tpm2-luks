#!/bin/sh

export TPM2TOOLS_TCTI=device:/dev/tpmrm0
export TPM2TOOLS_TCTI_NAME=device
export TPM2TOOLS_DEVICE_FILE=/dev/tpmrm0
DISK="/dev/disk/by-uuid/UUID_ROOT_PARTITION"
TMPDIR=$(mktemp -d)
TPM_SLOT="2"
umask 0077

#Get the PCRs 0,2,4,9,11,12,14 as a binary file
tpm2_pcrlist -Q -L sha256:0,2,4,9,11,12,14 -o "$TMPDIR/pcr.digest"
if [ $? -ne 0 ]
then
    rm -rf "$tmpdir"
    exit $?
fi

/opt/tpmdisk/renew-encryption.sh "$TMPDIR/pcr.digest"
