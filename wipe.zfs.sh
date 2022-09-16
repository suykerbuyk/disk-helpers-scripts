#!/bin/bash

LUN_PATTERN=" /dev/disk/by-id/wwn-0x5000c500d*"
for P in $(zpool list | grep destor | awk '{print $1}')
do
	echo "zpool destroy $P"
	zpool destroy $P &
done
echo "Waiting for pool destruction..."
wait
# clear out the primary ZFS partion
for X in $(ls ${LUN_PATTERN} | grep part1)
do
	zpool labelclear -f ${X} &
done
echo "Waiting for labelclear..."
wait
for X in $(ls ${LUN_PATTERN} | grep part1)
do
	wipefs -a ${X} &
done
echo "Waiting for the wiping of partition 1"
wait

# clear out the residual end of disk partition
for X in $(ls ${LUN_PATTERN} | grep part9)
do
	wipefs -a ${X} &
done
echo "Waiting for the wiping of partition 9"
wait

# Finally, wipe out the GPT partions.
for X in $(ls ${LUN_PATTERN} | grep -v part)
do
	sgdisk -Z ${X} &
done
echo "Waiting for zapdisk(s)"
wait
echo "Brining out the partprobe"
partprobe

# and finally, create a new pool
#zpool create cvt  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 draid2:4d:6c:0s  /dev/disk/by-id/wwn-0x600c0ff0005*
