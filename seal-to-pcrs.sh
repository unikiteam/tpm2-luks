#!/bin/sh

# args are: input priv pub

# KEEP IN SYNC!
PCRS="0 2 4 9 11 12 14"
PCR_BITS="5A15"
TOOLSDIR="/opt/tpmdisk"

tmpdir=$(mktemp -d)

# Read PCRs
for pcr in $PCRS
do
    "$TOOLSDIR/pcrread" -halg sha1 -ns -ha $pcr >>"$tmpdir/pcrs.txt"
done

# Make text policy file
"$TOOLSDIR/policymakerpcr" -halg sha1 -bm $PCR_BITS -if "$tmpdir/pcrs.txt" -of "$tmpdir/pcr-policy.txt"

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
"$TOOLSDIR/create" -halg sha1 -nalg sha1 -hp 81000001 -bl -kt p -kt f -pol "$tmpdir/pcr-policy.bin" -if "$1" -opr "$2" -opu "$3"

if [ $? -gt 0 ]
then
    >&2 echo "Seal to TPM failed!"
    rm -rf "$tmpdir"
    exit 1
fi

# Clean up
rm -rf "$tmpdir"
