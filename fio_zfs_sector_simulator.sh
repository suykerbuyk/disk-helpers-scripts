#!/bin/bash
set -e
#=======================================================
# For scripted use, we take the 1st parameter as a named
# function to call and parameter two as it's parameters
SCRIPTED_FUNCTION="$1"
SCRIPTED_FUNPARAM="$2"
MIN_ZFS_RECORD_SIZE=32768
POOL_NAME='ZPOOL_cl-al-710cd8'
LOGDIR="${HOSTNAME}_$(date --iso-8601)_336_2draid2_sector_sim_no_spec"
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

#PARENT_TESTFS="sectors_special_vdev"
PARENT_TESTFS="sectors_no_special_vdev"

if [ ! -d ${LOGDIR} ]; then
		mkdir ${LOGDIR}
fi

mk_test_sectors() {
for X in 1 2 4 8 16 32
do
	REC_SIZE=$((X * 32768))
	if [ ! -d "/${POOL_NAME}/${PARENT_TESTFS}/rec_${REC_SIZE}" ]
	then
		FS="${POOL_NAME}/${PARENT_TESTFS}/rec_${REC_SIZE}"
		zfs create -p "${FS}" -o recordsize=${REC_SIZE} && \
		#zfs set special_small_blocks=16384 "${FS}" && \
		zfs wait "${FS}"
	fi
done
for D in $(find /${POOL_NAME}/${PARENT_TESTFS}/* -maxdepth 1 -type d)
do
	REC="$(echo $D | awk -F '_' '{print $3}')"
	for F in $(seq 0 255)
	do
		TGT="${D}/sector.${F}"
		# if we have a special vdev, the actual du file sizes vary.
		if [ ! -f ${TGT} ] ||  [ "32G" != "$(du -kh $TGT | cut -f1)" ] ; then
			echo -n "Creating $TGT  "
			dd if=/dev/zero bs=1G count=32 oflag=sync of="${TGT}" 2>&1 | grep -v ' records ' || true
		#else
		#	echo "Skipping ${TGT}"
		fi
	done
done
}

mk_test_sectors

#dmesg -C
#echo "Start: $SCRIPT_NAME">/dev/kmsg
#echo 1 > /sys/module/zfs/parameters/zfs_disable_failfast
#echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_read_max_active
#echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_write_max_active
#echo 2048 >/sys/module/zfs/parameters/zfs_vdev_max_active
zpool events -c
echo "Start: $SCRIPT_NAME">/dev/kmsg
echo $((96 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_arc_max
echo $((96 * 1024 * 1024 *1024)) > /sys/module/zfs/parameters/zfs_arc_min
#echo 8192 >/sys/module/zfs/parameters/zfs_vdev_ms_count_limit || true
#echo 16777216 >/sys/module/zfs/parameters/zfs_vdev_aggregation_limit || true
#echo 16777216 >/sys/module/zfs/parameters/zfs_max_recordsize || true
#echo 256 >/sys/module/zfs/parameters/zfs_vdev_def_queue_depth || true
#echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_read_max_active || true
#echo 64 >/sys/module/zfs/parameters/zfs_vdev_sync_read_max_active || true
#echo 64 >/sys/module/zfs/parameters/zfs_vdev_async_write_max_active || true
#echo 64 >/sys/module/zfs/parameters/zfs_vdev_sync_write_max_active || true
#echo 64 >/sys/module/zfs/parameters/zfs_commit_timeout_pct || true
#echo 16777216 >/sys/module/zfs/parameters/metaslab_aliquot || true
#echo 51539607552 >/sys/module/zfs/parameters/zfs_dirty_data_max || true
#echo 8 >/sys/module/spl/parameters/spl_kmem_cache_kmem_threads || true
#echo 64 >/sys/module/spl/parameters/spl_kmem_cache_obj_per_slab || true
#echo 1024 >/sys/module/spl/parameters/spl_kmem_cache_max_size || true
echo 0x0006020A >/sys/module/mpt3sas/parameters/logging_level

for IOENGINE in libaio ; do
	for IODEPTH in 1 32; do
	#for IODEPTH in 32 64; do
		for JOBS in 1 4 8 16 32 64 96 128; do
		#for JOBS in 16 32 64 96 128; do
			for PAT in 'randread' 'read' ; do
			#for PAT in 'read' ; do
				for BLK in 4096 8192 16384 32768 65536; do
					for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}'); do
						for REC in 32768 65536 131072 262144 524288 1048576; do
							BLK_NAME="$(printf %08d $BLK)"
							[ "${REC}" -lt ${MIN_ZFS_RECORD_SIZE} ] && REC=${MIN_ZFS_RECORD_SIZE}
							REC_NAME="$(printf %08d $REC)"
							echo "REC is now $REC"
							TEST="${POOL}_sector_sim_with_spec-${IOENGINE}-${IODEPTH}-${PAT}-${JOBS}-${REC_NAME}-${BLK_NAME}.fio.json"
							TEST_FS="${POOL}/${PARENT_TESTFS}/rec_${REC}"
							#echo "Creating ${TEST_FS}"
							#zfs create -p -o recordsize=${REC} -o compression=off ${TEST_FS}
							#zpool wait -t initialize ${POOL}
							#zfs set special_small_blocks=16384 ${TEST_FS}
							echo "TEST_FS=${TEST_FS}"
							echo "Running $TEST"
							fio --directory=/${TEST_FS} \
							    --name="${TEST}" \
							    --size=32G \
							    --rw=$PAT \
							    --group_reporting=1 \
							    --bs=$BLK \
							    --direct=1 \
							    --numjobs=$JOBS \
							    --time_based=1 \
							    --runtime=30 \
							    --random_generator=tausworthe64 \
							    --end_fsync=1 \
							    --fallocate=truncate \
							    --iodepth=$IODEPTH \
							    --filename_format='sector.$jobnum'\
							    --ioengine=$IOENGINE \
							    --output-format=json | tee "$PWD/${LOGDIR}/${TEST}" && \
							echo "Completed" 
						done
						wait
					done
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
