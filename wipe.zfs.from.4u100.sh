#!/bin/bash

for P in $(zpool list | grep cvt | awk '{print $1}')
do
        echo "zpool destroy $P"
        zpool destroy $P
done
LUN_PATTERN="/dev/disk/by-id/wwn-0x5000c5*"
# clear out the primary ZFS partion
for X in $(ls ${LUN_PATTERN} | grep part1)
do
        zpool labelclear -f ${X}
        wipefs -a ${X}
done

# clear out the residual end of disk partition
for X in $(ls ${LUN_PATTERN} | grep part9)
do
        wipefs -a ${X}
done

# Finally, wipe out the GPT partions.
for X in $(ls ${LUN_PATTERN} | grep -v part)
do
        sgdisk -Z ${X}
done

