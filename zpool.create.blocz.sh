#!/bin/bash
#set -e

RAIDZ1A="/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR50N2A3 \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR50V319 \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR50VM3C \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR50YMQL \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR517SXT \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51BC7L \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51D22H \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51DQ0S \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51GQQ1 "

RAIDZ1B="/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51KSGE \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51L2WJ \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51LEVT \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51LQNB \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51N7TZ \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51NPL4 \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51QY4F \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZR51T3NF \
	/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZRS00Q0Y "

SPARE="/dev/disk/by-id/scsi-SATA_ST16000NM000J-2T_ZRS00Q8T"

SPEC_VDEVS="/dev/nvme0n1 /dev/nvme1n1"
CACHE="/dev/nvme2n1"

ZPOOL_PROPS="\
	-o autoreplace=on\
	-o autotrim=on\
	-o ashift=12"
ZFS_PROPS="\
	-O recordsize=512K\
	-O atime=off\
	-O dnodesize=auto\
	-O sync=disabled "

POOL_NAME="$(hostname)"
POOL_MOUNT="/stor"
POOL_OPTS="-m ${POOL_MOUNT}"

make_pool() {
zpool create "${POOL_NAME}" ${POOL_OPTS} ${ZPOOL_PROPS} ${ZFS_PROPS}\
	raidz1 ${RAIDZ1A}\
	raidz1 ${RAIDZ1B}\
	spare ${SPARE} \
	cache ${CACHE}
	zpool wait ${POOL_NAME} -t initialize
	#zpool add  -o special_small_blocks=64k -o ashift=12 ${POOL_NAME} special  mirror ${SPEC_DEVS}
	zpool add   -o ashift=12 ${POOL_NAME} special  mirror ${SPEC_VDEVS}
	#zpool add  stor4 special  mirror /dev/nvme0n1 /dev/nvme1n1
	zpool wait ${POOL_NAME} -t initialize
	zfs set special_small_blocks=64k ${POOL_NAME}
}
show_devices(){
	for X in ${RAIDZ1A}; do echo "RAIDZ1A: ${X}"; done
	for X in ${RAIDZ1B}; do echo "RAIDZ1B: ${X}"; done
	for X in ${SPARE}; do echo "  SPARE: ${X}"; done
	for X in ${CACHE}; do echo "  CACHE: ${X}"; done
}
clear_devices() {
	zpool status ${POOL_NAME} &>/dev/null
	if [ $? == 1 ]
	then
		echo "zpool ${POOL_NAME} is not present"
	else
		echo "Will destroy pool ${POOL_NAME}"
		zpool destroy ${POOL_NAME}
	fi
	for X in ${RAIDZ1A} ${RAIDZ2} ${SPARE} ${CACHE}
	do
		if [ -e ${X}-part1 ] 
		then
			zpool labelclear ${X}
			wipefs -a ${X}
		fi
		sgdisk -Z ${X} &
	done
	echo "Waiting for all jobs to complete"
	wait
	echo "Done"
}
#show_devices
clear_devices
make_pool
