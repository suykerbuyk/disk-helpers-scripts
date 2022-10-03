#!/bin/bash
set -e
POOL_NAME=DESTOR
EVANS='wwn-0x5000c500c'
CORVAULT='wwn-0x600c0ff000'
LUN_PATTERN="/dev/disk/by-id/${EVANS}*"
LOGDIR=test

if [ ! -d ${LOGDIR} ]; then
	mkdir ${LOGDIR}
fi

LUN_COUNT=$(ls $LUN_PATTERN | grep -v part| wc -l )
echo "LUN_COUNT=$TGT_COUNT"

SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

wipe_zfs_pools() {
	for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}')
	do
		umount /${POOL}
		echo "zpool destroy $POOL"
		zpool destroy $POOL &
	done
	wait
	# clear out the primary ZFS partion
	for X in $(ls ${LUN_PATTERN} | grep part1)
	do
		echo "zpool labelclear -f ${X} && wipefs -a ${X}"
		zpool labelclear -f ${X} && wipefs -a ${X} &
	done
	wait

	# clear out the residual end of disk partition
	for X in $(ls ${LUN_PATTERN} | grep part9)
	do
		echo "wipefs -a ${X}"
		wipefs -a ${X} &
	done
	wait

	# Finally, wipe out the GPT partions.
	for X in $(ls ${LUN_PATTERN} | grep -v part)
	do
		echo "sgdisk -Z ${X}"
		sgdisk -Z ${X} &
	done
	wait
	sleep 1
	partprobe &
	echo "Waiting for partprobe"
	wait
}

rescan_scsi_bus() {
	# Rescan the SCSI bus
	for X in $(ls /sys/class/scsi_host/)
	do
		echo "- - -" > /sys/class/scsi_host/$X/scan &
	done
	wait
}

create_draid_zpool() {
	wipe_zfs_pool
	zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 draid2:4d:6c:0s  ${LUN_PATTERN}
}
create_5u84_draid2_10_zpool() {
	wipe_zfs_pools
	zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 draid2:10d:${LUN_COUNT}c:4s  ${LUN_PATTERN}
}
create_5u84_draid2_8_zpool() {
	wipe_zfs_pools
	zpool create ${POOL_NAME}  -O recordsize=32K -O atime=off -O dnodesize=auto -o ashift=12 draid2:8d:${LUN_COUNT}c:4s  ${LUN_PATTERN}
}
create_raidz2_zpool() {
	wipe_zfs_pool
	zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 raidz2  ${LUN_PATTERN}
}
create_individual_pools() {
	wipe_zfs_pools
	IDX=0
	for X in $(ls ${LUN_PATTERN} | grep -v part | grep -v '00c0ff512e8100003801326201000000' )
	do
		zpool create ${POOL_NAME}_${IDX}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 $X
		IDX=$((IDX+1))
	done
}


#create_individual_pools
#create_5u84_draid_zpool
#create_5u84_draid2_8_zpool
#wipe_zfs_pools
#clear all dmesg history
dmesg -C
echo $((32 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_arc_max
echo 0x0006020A >/sys/module/mpt3sas/parameters/logging_level
echo "Start: $SCRIPT_NAME">/dev/kmsg
for IOENGINE in libaio io_uring; do
	for IODEPTH in 1 8 16 32; do
		for JOBS in 1 4 8 16 32; do
			for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
				for BLK in 4096 8192 16384 32768 131072 262144 524288 1048576 4194304 16777216; do
					for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}')
					do
						TEST="${POOL}-${IOENGINE}-${IODEPTH}-${PAT}-${BLK}-${JOBS}.fio.json"
						echo "Running $TEST"
						zpool clear ${POOL}
						$PWD/fio-3.30 --directory=/${POOL} \
						    --name="${TEST}" \
						    --size=128G \
						    --rw=$PAT \
						    --group_reporting=1 \
						    --bs=$BLK \
						    --direct=1 \
						    --numjobs=$JOBS \
						    --time_based=1 \
						    --runtime=30 \
						    --random_generator=tausworthe64 \
						    --iodepth=$IODEPTH \
						    --ioengine=$IOENGINE \
						    --output-format=json | tee "$PWD/${LOGDIR}/${TEST}" && \
						echo "Completed" &
					done
					wait
				done
			done
		done
	done
done
echo "Stop: $SCRIPT_NAME">/dev/kmsg
