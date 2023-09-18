#/bin/bash

# Theory:
# draid2:18d:168c:1s
#  zfs record size: 288k = 16k per data disk  (18 * 16k) 1 spare.
# 18d + 2p + 1s = 21 disk per 288k stripe.
# 168 child disk / 21 = 8 vdevs across two JBODs.
#  
ZPOOL_NAME="altlabs01"
ZPOOL_ASHIFT="12"
ZPOOL_AUTO_TRIM="on"
ZFS_RECORD_SIZE="$((1024*1024))"
ZFS_ATIME='off'
ZFS_COMPRESSION='off'
ZFS_DNODE_SIZE='auto'
ZFS_SYNC='disabled'
ZPOOL_COMMENT="Test_Pool"
ZFS_MAX_RECORD_SIZE="$((1024*1024*16))"
ZFS_SPECIAL_SMALL_BLOCK_SIZE="128k"

SPECIAL_VDEVS="/dev/disk/by-id/nvme-WUS3BA138C7P3E3_A06463B1 /dev/disk/by-id/nvme-WUS3BA138C7P3E3_A05A135F"

mk_single_jbod() {
	BACKING_VDEVS='/dev/disk/by-id/dm-uuid-mpath-35000c500d*'
	ZFS_PROPS="-O atime=${ZFS_ATIME} -O recordsize=${ZFS_RECORD_SIZE}\
	 -O dnodesize=${ZFS_DNODE_SIZE} -O sync=${ZFS_SYNC} -O compression=${ZFS_COMPRESSION}"
	ZPOOL_PROPS="-o ashift=${ZPOOL_ASHIFT} -o comment=\"${ZPOOL_COMMENT}\" -o autotrim=${ZPOOL_AUTO_TRIM}"
	zpool create "${ZPOOL_NAME}" draid2:8d:168c:8s  ${ZPOOL_PROPS} ${ZFS_PROPS} ${BACKING_VDEVS}
}
mk_large_jbod(){
	. ./disk.groups
	ZFS_PROPS="-O atime=${ZFS_ATIME} -O recordsize=${ZFS_RECORD_SIZE}\
	 -O dnodesize=${ZFS_DNODE_SIZE} -O sync=${ZFS_SYNC} -O compression=${ZFS_COMPRESSION}"
	ZPOOL_PROPS="-o ashift=${ZPOOL_ASHIFT} -o comment=\"${ZPOOL_COMMENT}\" -o autotrim=${ZPOOL_AUTO_TRIM}"
	zpool create "${ZPOOL_NAME}" ${ZPOOL_PROPS} ${ZFS_PROPS}\
		draid2:8d:84c:4s ${DSKGRP1}\
		draid2:8d:84c:4s ${DSKGRP2}\
		draid2:8d:84c:4s ${DSKGRP3}\
		draid2:8d:84c:4s ${DSKGRP4}
}
mk_large_jbod
