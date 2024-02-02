#!/bin/bash
POOL_NAME="cl-al-710cd8"
#LUN_PATTERN="/dev/disk/by-id/wwn-0x5000c500d*"
LUN_PATTERN="/dev/disk/by-vdev/HLF1016437G00*"
#SPECIAL_VDEVS="$(ls /dev/disk/by-id | grep nvme-KCM6XRUL | grep -v part | grep -ve '_1$' | tr '\n' ' ')"
#SPECIAL_VDEVS="$(ls /dev/disk/by-id | grep nvme-KCM6XRUL | grep -v part | tr '\n' ' ')"
SPECIAL_VDEVS="$(ls /dev/disk/by-id/nvme-eui.00000000000000008ce38ee2* | grep -v part | tr '\n' ' ')"

for P in $(zpool list | grep "${POOL_NAME}" | awk '{print $1}')
do
	echo "zpool destroy $P"
	zpool destroy $P &
done
echo "Waiting for pool destruction..."
wait
# clear out the primary ZFS partion
for X in $(ls ${LUN_PATTERN} | grep part1) ${SPECIAL_VDEVS}
do
	if [ -f $X ] ; then
		zpool labelclear -f ${X} &
	fi
done
echo "Waiting for labelclear..."
wait
for X in $(ls ${LUN_PATTERN} | grep part1) ${SPECIAL_VDEVS} 
do
	wipefs -a ${X} &
done
echo "Waiting for the wiping of partition 1"
wait

# clear out the residual end of disk partition
for X in $(ls ${LUN_PATTERN} | grep part9) ${SPECIAL_VDEVS} 
do
	wipefs -a ${X} &
done
echo "Waiting for the wiping of partition 9"
wait

# Finally, wipe out the GPT partions.
for X in $(ls ${LUN_PATTERN} | grep -v part) ${SPECIAL_VDEVS} 
do
	sgdisk -Z ${X} &
done
echo "Waiting for zapdisk(s)"
wait
echo "Bringing out the partprobe"
partprobe

# and finally, create a new pool
#zpool create cvt  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 draid2:4d:6c:0s  /dev/disk/by-id/wwn-0x600c0ff0005*
