#!/bin/bash
set -e
#=======================================================
# For scripted use, we take the 1st parameter as a named
# function to call and parameter two as it's parameters
SCRIPTED_FUNCTION="$1"
SCRIPTED_FUNPARAM="$2"

#=======================================================
# Patterns to look for in /dev/disk/by-id/ to use as 
# storage targets.  Get this wrong and you might wipe
# your boot devices!
EVANS_WWN_BASE='wwn-0x5000c500c'
MACH2_WWN_BASE='wwn-0x6000c500a'
TATSU_WWN_BASE='wwn-0x5000c5009'
CRVLT_WWN_BASE='wwn-0x600c0ff00'
OSPRY_ATA_BASE='ata-ST18000NM00'
#OSPRY_ATA_BASE='wwn-0x5ace42e02'
OSPRY_SAS_BASE='wwn-0x6000c500d'

X2LUN_SEP='0001000000000000'

POOL_NAME=STXTEST

SPEC_VDEV=/dev/nvme0n1
TARGET="${CRVLT_WWN_BASE}"
LUN_PATTERN="/dev/disk/by-id/${TARGET}*"
MIN_ZFS_RECORD_SIZE=131072
LOGDIR="cvt_tuned_$(date --iso-8601)_post_init_special_vdev_fixed_rec_2097152"

SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

if [ ! -d ${LOGDIR} ]; then
	mkdir ${LOGDIR}
fi

LUN_COUNT=$(ls $LUN_PATTERN | grep -v part| wc -l )
echo "LUN_COUNT=$LUN_COUNT"
cp "${SCRIPT_NAME}" "${LOGDIR}/"


wipe_zfs_pools() {
	POOL_BASE_NAME=$(echo $POOL_NAME | awk -F '_' '{print $1}')
	for POOL in $(zpool list -H | grep ${POOL_BASE_NAME} | awk '{print $1}')
	do
		umount -R /${POOL}
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
find_corvault_a_controllers(){
	RET=""
	for TARG in $(ls /dev/disk/by-id/${TARGET}* |  grep -v part | sort)
	do
		PORT="$(sg_vpd --page=0x83 $TARG | grep "Relative target port:" | sed 's|.*Relative target port: 0x||g')"
		[[ $PORT < 5 ]] && RET="$RET $TARG"
	done
	printf "$RET"
}
find_corvault_b_controllers(){
	RET=""
	for TARG in $(ls /dev/disk/by-id/${TARGET}* |  grep -v part | sort)
	do
		PORT="$(sg_vpd --page=0x83 $TARG | grep "Relative target port:" | sed 's|.*Relative target port: 0x||g')"
		[[ $PORT > 4 ]] && RET="$RET $TARG"
	done
	printf "$RET"
}

create_draid_zpool() {
	wipe_zfs_pools
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
	wipe_zfs_pools
	zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 raidz2  ${LUN_PATTERN}
}
create_raidz1_corvault_zpool() {
	wipe_zfs_pools
	zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12\
	      raidz1 $(find_corvault_a_controllers) \
	      raidz1 $(find_corvault_b_controllers) 
	      zpool add ${POOL_NAME} -o ashift=12 special -f ${SPEC_VDEV}
	      zfs set special_small_blocks=8K ${POOL_NAME}
	#. ./tune.zfs.sh
	for X in $(ls -lah /dev/disk/by-id/wwn-0x600c0ff00* | grep -v part | awk -F '/' '{print $7}')
	do
		echo 8192 >/sys/block/$X/queue/max_sectors_kb
	done
}
create_stripe_zpool() {
	wipe_zfs_pools
	zpool create ${POOL_NAME}  -O recordsize=32k -O atime=off -O dnodesize=auto -o ashift=12 ${LUN_PATTERN}
	for X in $(ls -lah /dev/disk/by-id/wwn-0x600c0ff00* | grep -v part | awk -F '/' '{print $7}')
	do
		echo 8192 >/sys/block/$X/queue/max_sectors_kb
	done
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

#rescan_scsi_bus
#create_individual_pools
#create_5u84_draid_zpool
#create_5u84_draid2_8_zpool
#create_draid_zpool
#create_raidz2_zpool
#create_raidz1_corvault_zpool
#clear all dmesg history
#dmesg -C
#zpool create osprey draid2:8d:16c:0s /dev/disk/by-partlabel/${POOL_NAME}_* -O recordsize=1M -O atime=off -O dnodesize=auto -o ashift=12 cache /dev/nvme0n1
echo 0x0006020A >/sys/module/mpt3sas/parameters/logging_level
echo "Start: $SCRIPT_NAME">/dev/kmsg
#echo 1 > /sys/module/zfs/parameters/zfs_disable_failfast
#echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_read_max_active
#echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_write_max_active
#echo 2048 >/sys/module/zfs/parameters/zfs_vdev_max_active
zpool events -c
echo "Start: $SCRIPT_NAME">/dev/kmsg
create_raidz1_corvault_zpool
echo $((32 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_arc_max
echo $((32 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_arc_min
echo 8192 >/sys/module/zfs/parameters/zfs_vdev_ms_count_limit || true
echo 16777216 >/sys/module/zfs/parameters/zfs_vdev_aggregation_limit || true
echo 16777216 >/sys/module/zfs/parameters/zfs_max_recordsize || true
echo 256 >/sys/module/zfs/parameters/zfs_vdev_def_queue_depth || true
echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_read_max_active || true
echo 64 >/sys/module/zfs/parameters/zfs_vdev_sync_read_max_active || true
echo 64 >/sys/module/zfs/parameters/zfs_vdev_async_write_max_active || true
echo 64 >/sys/module/zfs/parameters/zfs_vdev_sync_write_max_active || true
echo 64 >/sys/module/zfs/parameters/zfs_commit_timeout_pct || true
echo 16777216 >/sys/module/zfs/parameters/metaslab_aliquot || true
echo 51539607552 >/sys/module/zfs/parameters/zfs_dirty_data_max || true
echo 8 >/sys/module/spl/parameters/spl_kmem_cache_kmem_threads || true
echo 64 >/sys/module/spl/parameters/spl_kmem_cache_obj_per_slab || true
echo 1024 >/sys/module/spl/parameters/spl_kmem_cache_max_size || true
create_raidz1_corvault_zpool

echo 0x0006020A >/sys/module/mpt3sas/parameters/logging_level
#for IOENGINE in libaio io_uring; do
for IOENGINE in libaio ; do
	#for IODEPTH in 1 8 16 32; do
	for IODEPTH in 1 16 32; do
		#for JOBS in 1 4 8 16 32; do
		for JOBS in 1 4 8 16; do
			for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
				#for BLK in 4096 8192 16384 32768 131072 262144 524288 1048576 4194304 16777216; do
				for BLK in 4096 8192 16384 32768 131072 262144 524288 1048576; do
					for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}')
					do
						BLK_NAME="$(printf %08d $BLK)"
						TEST="${POOL}-${IOENGINE}-${IODEPTH}-${PAT}-${BLK_NAME}-${JOBS}.fio.json"
						TESTFS="${POOL}/TEST/BLK_${BLK_NAME}"
						echo "Creating ${TESTFS}"
						#[ "${BLK}" -lt ${MIN_ZFS_RECORD_SIZE} ] && BLK=${MIN_ZFS_RECORD_SIZE}
						#echo "BLK is now $BLK"
						#zfs create -p -o recordsize=${BLK} -o compression=off ${TESTFS}
						zfs create -p -o recordsize=2097152 -o compression=off ${TESTFS}
						zpool wait -t initialize ${POOL}
						echo "Running $TEST"
						fio --directory=/${TESTFS} \
						    --name="${TEST}" \
						    --size=100G \
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
zpool status -v ${POOL_NAME} >${LOGDIR}/zpool.status.log
zfs get all ${POOL_NAME} >${LOGDIR}/zfs.props.log
zpool get all ${POOL_NAME} >${LOGDIR}/zpool.props.log
#zdb -Lbbbs ${POOL_NAME} >${LOGDIR}/zdb.Lbbbs.log
cd ${LOGDIR} && ../analyze.fio.json.sh | tee ${LOGDIR}.csv ; cd -
