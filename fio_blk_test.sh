#!/bin/bash
set -e
POOL_NAME=cvt
#LUN_PATTERN="/dev/disk/by-id/wwn-0x600c0ff000*"
LUN_PATTERN="/dev/disk/by-id/scsi-SSEAGATE_ST18000NM004J_ZR5046D00000C2022HZJ*"
LOGDIR=test

if [ ! -d ${LOGDIR} ]; then
	mkdir ${LOGDIR}
fi

SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"


wipe_zfs_pools() {
	for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}')
	do
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


#wipe_zfs_pools
#rescan_scsi_bus
#create_individual_pools
#clear all dmesg history
#dmesg -c
echo "Start: $SCRIPT_NAME">/dev/kmsg
for IOENGINE in libaio io_uring ; do
	for IODEPTH in 1 8 16 32; do
		for JOBS in 1 4 8 16 32; do
			for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
				for BLK in 4096 8192 16384 32768 131072 262144 524288 1048576 4194304 16777216; do
				#for BLK in 1024k 8192k 32768k; do
					for BLKDEV in $(ls $LUN_PATTERN | sed 's:/dev/disk/by-id/::g' | head -10)
					do
						BLKDEV_KDEV="$(readlink /dev/disk/by-id/${BLKDEV} |  tr -d '.|\/')"
						BLKDEV_NAME="${BLKDEV}_${BLKDEV_KDEV}"
						BLKDEV_NAME="$(echo $BLKDEV_NAME | sed 's/-/_/g')"
						TEST="${BLKDEV_NAME}-${IOENGINE}-${IODEPTH}-${PAT}-${BLK}-${JOBS}.fio.json"
						echo "Running $TEST"
						fio --filename=/dev/disk/by-id/${BLKDEV} \
						    --name="${TEST}" \
						    --size=1024G \
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
