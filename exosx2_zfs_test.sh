#!/bin/bash
set -e
POOL_NAME=STXTEST
EVANS='wwn-0x5000c500c'
CORVAULT='wwn-0x600c0ff000'
LUN_PATTERN="/dev/disk/by-id/${EVANS}*"
LOGDIR=OspreyRaidZ1_2VDEVS_10_drives

if [ ! -d ${LOGDIR} ]; then
	mkdir ${LOGDIR}
fi

SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

dmesg -C
#zpool create osprey draid2:8d:16c:0s /dev/disk/by-partlabel/${POOL_NAME}_* -O recordsize=1M -O atime=off -O dnodesize=auto -o ashift=12 cache /dev/nvme0n1


#echo 1 > /sys/module/zfs/parameters/zfs_disable_failfast
#echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_read_max_active
#echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_write_max_active
#echo 2048 >/sys/module/zfs/parameters/zfs_vdev_max_active
zpool events -c
echo "Start: $SCRIPT_NAME">/dev/kmsg
#echo 16777216 > /sys/module/zfs/parameters/zfs_max_recordsize
echo $((16 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_arc_min
echo $((32 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_arc_max
#echo $((8 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_dirty_data_max
echo 0x0006020A >/sys/module/mpt3sas/parameters/logging_level
#for IOENGINE in libaio io_uring; do
for IOENGINE in libaio ; do
	#for IODEPTH in 1 8 16 32; do
	for IODEPTH in 16 32 64; do
		#for JOBS in 1 4 8 16 32; do
		for JOBS in 1 4; do
			for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
				#for BLK in 4096 8192 16384 32768 131072 262144 524288 1048576 4194304 16777216; do
				#for BLK in 4096 8192 16384 32768 131072 262144 524288 1048576; do
				#for BLK in 4194304 1048576 524288 262144 131072 32768 16384 ; do
				for BLK in 1048576 524288 262144 131072 32768 16384 ; do
					for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}')
					do
						TEST="${POOL}-${IOENGINE}-${IODEPTH}-${PAT}-${BLK}-${JOBS}.fio.json"
						TESTFS="${POOL}/TEST/BLK_${BLK}"
						echo "Creating ${TESTFS}"
						zfs create -p -o recordsize=${BLK} ${TESTFS}
						zpool wait -t initialize ${POOL}
						echo "Running $TEST"
						fio --directory=/${TESTFS} \
						    --name="${TEST}" \
						    --size=1T \
						    --rw=$PAT \
						    --group_reporting=1 \
						    --bs=$BLK \
						    --direct=1 \
						    --numjobs=$JOBS \
						    --time_based=1 \
						    --runtime=240 \
						    --random_generator=tausworthe64 \
						    --end_fsync=1 \
						    --fallocate=truncate \
						    --iodepth=$IODEPTH \
						    --filename_format='fio_test.$filenum.$jobnum'\
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
zpool status -v ${POOL_NAME} >${LOGDIR}/osprey.status.log
zfs get all ${POOL_NAME} >${LOGDIR}/zfs.props.log
zpool get all ${POOL_NAME} >${LOGDIR}/zpool.props.log
zdb -Lbbbs ${POOL_NAME} >${LOGDIR}/zdb.Lbbbs.log
cd ${LOGDIR} && ../analyze.fio.json.sh | tee ${LOGDIR}.csv ; cd -

