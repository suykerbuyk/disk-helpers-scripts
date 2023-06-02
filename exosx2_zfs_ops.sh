#!/usr/bin/env bash

# set bash to die on command failure
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

#=======================================================
# Inventory storage targets
OSPRY_ATA_LUNS=( $(ls /dev/disk/by-id/${OSPRY_ATA_BASE}* 2>/dev/null | grep -v part || true ) )
OSPRY_SAS_LUNS=( $(ls /dev/disk/by-id/${OSPRY_SAS_BASE}* | grep -v ${X2LUN_SEP} 2>/dev/null | grep -v part || true ) )
EVANS_SAS_LUNS=( $(ls /dev/disk/by-id/${EVANS_WWN_BASE}* 2>/dev/null | grep -v part || true ) )
MACH2_SAS_LUNS=( $(ls /dev/disk/by-id/${MACH2_WWN_BASE}* 2>/dev/null | grep -v part || true ) )
TATSU_SAS_LUNS=( $(ls /dev/disk/by-id/${TATSU_WWN_BASE}* 2>/dev/null | grep -v part || true ) )
CRVLT_SAS_LUNS=( $(ls /dev/disk/by-id/${CRVLT_WWN_BASE}* 2>/dev/null | grep -v part || true ) )
OSPRY_ATA_LUN_CNT="${#OSPRY_ATA_LUNS[*]}"
OSPRY_SAS_LUN_CNT="${#OSPRY_SAS_LUNS[*]}"
EVANS_SAS_LUN_CNT="${#EVANS_SAS_LUNS[*]}"
MACH2_SAS_LUN_CNT="${#MACH2_SAS_LUNS[*]}"
TATSU_SAS_LUN_CNT="${#TATSU_SAS_LUNS[*]}"
CRVLT_SAS_LUN_CNT="${#CRVLT_SAS_LUNS[*]}"

#=======================================================
# we identify metadata and cache devices as ther is not generally
# a safe, algorithmic approach to identifying them.
# You MUST change these devices and paths to match the device paths
# of your environment.
declare -a ZFS_SPECIAL_LUNS=()
declare -a ZFS_CACHE_LUNS=()
#declare -a ZFS_SPECIAL_LUNS=(\
#	"/dev/disk/by-id/nvme-SHPP41-2000GM_SDBCN63771060CS1V"\
#	"/dev/disk/by-id/nvme-SHPP41-2000GM_SDBCN63771060CS25"\
#)
#declare -a ZFS_CACHE_LUNS=(\
#	"/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_224519803014"\
#)
declare -a ZFS_LOG_LUNS=()
#declare -a ZFS_LOG_LUNS=(\
#	"/dev/disk/by-id/nvme-SHPP41-2000GM_SDBCN63771060CS1D"
#)

ZFS_SPECIAL_LUN_CNT="${#ZFS_SPECIAL_LUNS[@]}"
ZFS_CACHE_LUN_CNT="${#ZFS_CACHE_LUNS[@]}"
ZFS_LOG_LUN_CNT="${#ZFS_LOG_LUNS[@]}"

#=======================================================
# ZFS/ZPool settings
#
# Avoid adding '_' to ZPOOL_NAME values as in test cases
# where we create multiple pools, we'll suffix pull name
# with a deterministic suffix to name the pools
ZPOOL_NAME="STXTEST"
ZPOOL_COMMENT="STX_TEST"
ZPOOL_ASHIFT="12"
ZPOOL_AUTO_TRIM="on"
ZFS_RECORD_SIZE="$((1024*1024*1))"
ZFS_ATIME='off'
ZFS_COMPRESSION='off'
ZFS_DNODE_SIZE='auto'
ZFS_SYNC='disabled'
ZFS_MAX_RECORD_SIZE="$((1024*1024*1))"
ZFS_SPECIAL_SMALL_BLOCK_SIZE="32K"

#=======================================================



#=======================================================
# LVM settings to be applied when appropriate.
VG_PREFIX='VG_STXTEST'
LV_PREFIX='LV_STXTEST'
LVM_STRIPE_WIDTH="2M"

#=======================================================
# Setup for some logging
#SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
THIS_SCRIPT="${THIS_SCRIPT:=$(realpath $0)}"
THIS_SCRIPT_DIR="${THIS_SCRIPT_DIR:=$(dirname ${THIS_SCRIPT})}"
THIS_SCRIPT_BASE_NAME="${THIS_SCRIPT_BASE_NAME:=$(basename ${THIS_SCRIPT} | sed -r 's/.sh$//g')}"
LOG_DIR="$PWD/logs"
LOG_FILE="$LOG_DIR/$(hostname -f)_${THIS_SCRIPT_BASE_NAME}_layout_$(date +'%Y-%m-%d_%H%M%S').log"
if [[ ! -d "${LOG_DIR}" ]]; then
	mkdir "${LOG_DIR}"
fi
touch $LOG_FILE

#=======================================================
# This is how we set our target storage devices.
# We could iterate against LUN counts, but that 
# would be less determistic than simply forcing it here.
declare -a TARGET_LUNS
TARGET_LUN_CNT=0
TARGET_DRV_ID=""
if [[ ${OSPRY_ATA_LUN_CNT} > ${TARGET_LUN_CNT} ]]; then
	TARGET_LUNS=(${OSPRY_ATA_LUNS[*]})
	TARGET_LUN_CNT=${#TARGET_LUNS[*]}
	TARGET_DRV_ID=${OSPRY_ATA_BASE}
elif [[ ${OSPRY_SAS_LUN_CNT} > ${TARGET_LUN_CNT} ]]; then
	TARGET_LUNS=(${OSPRY_SAS_LUNS[*]})
	TARGET_LUN_CNT=${#TARGET_LUNS[*]}
	TARGET_DRV_ID=${OSPRY_SAS_BASE}
elif [[ ${EVANS_SAS_LUN_CNT} > ${TARGET_LUN_CNT} ]]; then
	TARGET_LUNS=(${EVANS_SAS_LUNS[*]})
	TARGET_LUN_CNT=${#TARGET_LUNS[*]}
	TARGET_DRV_ID=${EVANS_SAS_BASE}
elif [[ ${MACH2_SAS_LUN_CNT} > ${TARGET_LUN_CNT} ]]; then
	TARGET_LUNS=(${MACH2_SAS_LUNS[*]})
	TARGET_LUN_CNT=${#TARGET_LUNS[*]}
	TARGET_DRV_ID=${MACH2_SAS_BASE}
elif [[ ${TATSU_SAS_LUN_CNT} > ${TARGET_LUN_CNT} ]]; then
	TARGET_LUNS=(${TATSU_SAS_LUNS[*]})
	TARGET_LUN_CNT=${#TARGET_LUNS[*]}
	TARGET_DRV_ID=${TATSU_SAS_BASE}
elif [[ ${CRVLT_SAS_LUN_CNT} > ${TARGET_LUN_CNT} ]]; then
	TARGET_LUNS=(${CRVLT_SAS_LUNS[*]})
	TARGET_LUN_CNT=${#TARGET_LUNS[*]}
	TARGET_DRV_ID=${CRVLT_SAS_BASE}
fi
TARGET_LUN_PATTERN="/dev/disk/by-id/${TARGET_DRV_ID}*"

#=======================================================
# Show the discovered LUN counts
ShowLunCounts(){
	echo "TARGET_LUN_CNT=${TARGET_LUN_CNT}"
	echo "EVANS_SAS_LUN_CNT=${EVANS_SAS_LUN_CNT}"
	echo "MACH2_SAS_LUN_CNT=${MACH2_SAS_LUN_CNT}"
	echo "TATSU_SAS_LUN_CNT=${TATSU_SAS_LUN_CNT}"
	echo "CRVLT_SAS_LUN_CNT=${CRVLT_SAS_LUN_CNT}"
	echo "OSPRY_ATA_LUN_CNT=${OSPRY_ATA_LUN_CNT}"
	echo "OSPRY_SAS_LUN_CNT=${OSPRY_SAS_LUN_CNT}"
	echo "ZFS_SPECIAL_LUN_CNT=${ZFS_SPECIAL_LUN_CNT}"
	echo "ZFS_CACHE_LUN_CNT=${ZFS_CACHE_LUN_CNT}"
	echo "ZFS_LOG_LUN_CNT=${ZFS_LOG_LUN_CNT}"
}

#=======================================================
# Simple message output
msg() {
	printf "$@\n"
	[[ $GO_SLOW == 1 ]] && sleep 1
	return 0
}

#=======================================================
# Run a command but first tell the user what its going to do.
run() {
	#Print the command line, but trim extra white space.
	printf "$@ \n" | sed 's/\t/ /g' | sed 's/ \+/ /g' | tee -a "${LOG_FILE}"
	[[ 1 == $DRY_RUN ]] && return 0
	eval "$@"; ret=$?
	[[ $ret == 0 ]] && return 0
	printf " $@ - ERROR_CODE: $ret\n"
	exit $ret
}
#=======================================================
# Make sure we have our binary dependencies.
CheckForPreReqs() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	MISSING=""
	for CHK in wipefs sgdisk dialog awk sed
	do
		if ! [ -x "$(command -v $CHK)" ]
		then
			MISSING="$MISSING $CHK"
			echo "$CHK is missing"
		fi
	done
	if [ "X${MISSING}" != "X" ] ; then
		echo "Please install: $MISSING"
		exit 1
	fi
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

#=======================================================
# Show the discovered target LUNs
ShowTargetLuns(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	for LUN in ${TARGET_LUNS[*]}
	do
		echo "LUN: ${LUN}"
	done
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
#=======================================================
# Validate and display the extra/special vdevs
ValidateExtraZfsVdevs() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	if [[ ${#ZFS_SPECIAL_LUNS[@]} != 0 ]]
	then
		for VDEV in ${ZFS_SPECIAL_LUNS[*]}
		do
			if [[ ! -b ${VDEV} ]]
			then
				msg "ZFS Special VDEV $VDEV is missing, disabling special VDEV support."
				ZFS_SPECIAL_LUNS=();
				break;
			else
				msg "Verified Special VDEV: $VDEV"
			fi
		done
	else
		msg "No ZFS Special Luns found"
	fi
	if [[ ${#ZFS_CACHE_LUNS[@]} != 0 ]]
	then
		for VDEV in ${ZFS_CACHE_LUNS[*]}
		do
			if [[ ! -b ${VDEV} ]]
			then
				msg "ZFS CACHE VDEV $VDEV is missing, disabling CACHE VDEV support."
				ZFS_CACHE_LUNS=();
				break;
			else
				msg "Verified CACHE VDEV: $VDEV"
			fi
		done
	else
		msg "No ZFS Cache Luns found"
	fi
	if [[ ${#ZFS_LOG_LUNS[@]} != 0 ]]
	then
		for VDEV in ${ZFS_LOG_LUNS[*]}
		do
			if [[ ! -b ${VDEV} ]]
			then
				msg "ZFS LOG VDEV $VDEV is missing, disabling LOG VDEV support."
				ZFS_LOG_LUNS=();
				break;
			else
				msg "Verified LOG VDEV: $VDEV"
			fi
		done
	else
		msg "No ZFS Log Luns found"
	fi
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

echo "$ZFS_MAX_RECORD_SIZE" > /sys/module/zfs/parameters/zfs_max_recordsize
#zpool get comment OSPREY | grep OSPREY | awk '{print $3}'


#=======================================================
# Setup sd device scheduling and queing.
SetDiskScheduler() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	for DSK in ${TARGET_LUNS[*]} 
	do
		SD_DEV=$( ls -lah $DSK | awk -F '/' '{print $7}')
		#msg "# Setting scheduler for $DSK ($SD_DEV)"
		run "echo "none" >/sys/block/$SD_DEV/queue/scheduler" &
		#cat /sys/block/$SD_DEV/queue/scheduler
		#/sys/block/$SD_DEV/queue/read_ahead_kb
	done
	wait
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

#=======================================================
# basically a subset of the /usr/bin/rescan-scsi-bus.sh
# from sg3-utils
RescanScsiBus() {
	# Rescan the SCSI bus
	for X in $(ls /sys/class/scsi_host/)
	do
		run "echo '- - -' > /sys/class/scsi_host/$X/scan" &
	done
	wait
	sleep 1
	run "partprobe"
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

#=======================================================
# We dispatch from WipeTargetDisks to this so as to be
# able to run all "wipe" jobs in parallel.
WipeSingleDisk(){
	LUN="$1"
	if [[ "X" == "${LUN}X" ]] || [[ ! -e ${LUN} ]]
	then
		msg "WipeSingleDisk: missing or bad parameter - $LUN"
		exit 1
	fi
	for PART in $(ls ${LUN}* | grep part | sort -r)
	do
		run "wipefs -a ${PART} >/dev/null"
	done
	wait
	run "sgdisk -Z ${LUN} >/dev/null"
}

#=======================================================
# Removes partitioning structures.
WipeTargetDisks(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	for LUN in ${TARGET_LUNS[*]}
	do
		WipeSingleDisk ${LUN} &
	done
	wait

	for X in ${ZFS_SPECIAL_LUNS[*]}
	do
		run "sgdisk -Z ${X} >/dev/null" &
	done
	for X in ${ZFS_CACHE_LUNS[*]}
	do
		run "sgdisk -Z ${X} >/dev/null" &
	done
	for X in ${ZFS_LOG_LUNS[*]}
	do
		run "sgdisk -Z ${X} >/dev/null" &
	done
	wait
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
#=======================================================
# Cleans up and destroys ZFS pools
WipeZfsPools() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	POOL_BASE_NAME=$(echo ${ZPOOL_NAME} | awk -F '_' '{print $1}')
	for POOL in $(zpool list -H | grep ${POOL_BASE_NAME} | awk '{print $1}')
	do
		run "umount /${POOL} &>/dev/null || true"
		run "zpool destroy $POOL &>/dev/null || true" &
	done
	wait
        # clear out the primary ZFS partion
	for LUN in ${TARGET_LUNS[*]}
	do
		if [[ -e ${LUN}-part1 ]]
		then
                	run "zpool labelclear -f ${LUN}-part1 &>/dev/null || true " &
		fi
	done
	wait
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

#=======================================================
# Creates GPT partitions aligned to Osprey LBA splits
CreateOspreyPartitioning(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	ALIGN=$((1024*4))
	GPT_OVERHEAD=34
	for LUN in ${TARGET_LUNS[*]}
	do
		SERIAL=$(echo ${LUN} | awk -F '_' '{print $2}')
		LARGEST_END="$(sgdisk -a ${ALIGN} -E ${LUN} | grep -v Creating)"
		LARGEST_BEG="$(sgdisk -a ${ALIGN} -F ${LUN} | grep -v Creating)"
		TOTAL_SECTORS=$((GPT_OVERHEAD + LARGEST_END))
		MID_LBA=$((TOTAL_SECTORS/2))
		run "sgdisk -a ${ALIGN} -I \
			--new=1:$LARGEST_BEG:$((MID_LBA-$ALIGN-1))   --change-name=1:${ZPOOL_NAME}_A_${SERIAL} \
			--new=2:$((MID_LBA+$ALIGN)):0                --change-name=2:${ZPOOL_NAME}_B_${SERIAL} \
			${LUN} >/dev/null" &
	done
	wait
	sleep 1
	run "partprobe"
	sleep 1
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
#=======================================================
# Creates LVM volumes of Osprey GPT partitions
CreateOspreyLvmStripes(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	LVM_ZONE_COUNT='2'
	for PART1 in $(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_A_*);
	do
		PART2=$(echo $PART1| sed "s/_A_/_B_/g")
		SERIAL="$(echo $PART1 | awk -F '_' '{print $3}')"
		run "pvcreate -y $PART1  $PART2"
		run "vgcreate ${VG_PREFIX}_${SERIAL} $PART1 $PART2"
		run "lvcreate -y -i ${LVM_ZONE_COUNT}\
			-n ${LV_PREFIX}_${SERIAL}\
			-l 100%FREE --type striped\
			-I ${LVM_STRIPE_WIDTH}\
			${VG_PREFIX}_${SERIAL}"
	done
	run 'partprobe'
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

#=======================================================
# Removes LVM volumes from Osprey GPT partitions.
WipeOspreyLvmStripes(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	for VG in $(vgs | grep "${VG_PREFIX}" | awk '{print $1}')
	do
		PVS="$( pvs | grep $VG | awk '{print $1}' | tr '\n' ' ')"
		for LV in $(lvs | grep $VG | grep "${LV_PREFIX}" | awk '{print $1}')
		do
			 run "lvremove -y /dev/${VG}/$LV"
		done
		run "vgremove -y $VG"
		run "pvremove $PVS"
       	done
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
#=======================================================
# Preps for disk provisioning.
WipeDiskConfigs(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	ValidateExtraZfsVdevs
	WipeZfsPools
	WipeOspreyLvmStripes
	WipeTargetDisks
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
#=======================================================
# Provisions disk for LVM uses.
CreateOspreyLvmDiskConfig(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	WipeDiskConfigs
	CreateOspreyPartitioning
	CreateOspreyLvmStripes
	SetDiskScheduler
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
#=======================================================
# Povisions disks for ZFS Pools.
CreateOspreyZfsDiskConfig(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	WipeDiskConfigs
	CreateOspreyPartitioning
	SetDiskScheduler
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
#=======================================================
# Adds the "special" vdevs, if defined, to host metadata
# and small data IO.
AddZpoolSpecialVdevs() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	SPECIAL_VDEVS=""
	if [[ ${#ZFS_SPECIAL_LUNS[*]} != 0 ]]
	then
		if [[ ${#ZFS_SPECIAL_LUNS[*]} > 1 ]]
		then
			SPECIAL_VDEVS="mirror ${ZFS_SPECIAL_LUNS[*]}"
		else
			SPECIAL_VDEVS="${ZFS_SPECIAL_LUNS[0]}"
		fi
		run "zpool add ${ZPOOL_NAME} -o ashift=${ZPOOL_ASHIFT} -f special ${SPECIAL_VDEVS}"
		run "zfs set special_small_blocks=${ZFS_SPECIAL_SMALL_BLOCK_SIZE} ${ZPOOL_NAME}"
	else
		msg "No special devices to add"
	fi
}
#=======================================================
# Add ZFS intent log devices, if defined.
AddZpoolZilVdevs() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	SPECIAL_VDEVS=""
	if [[ ${#ZFS_LOG_LUNS[*]} != 0 ]]
	then
		if [[ ${#ZFS_LOG_LUNS[*]} > 1 ]]
		then
			SPECIAL_VDEVS="mirror ${ZFS_LOG_LUNS[*]}"
		else
			SPECIAL_VDEVS="${ZFS_LOG_LUNS[0]}"
		fi
		run "zpool add ${ZPOOL_NAME} -o ashift=${ZPOOL_ASHIFT} -f log ${SPECIAL_VDEVS}"
	else
		msg "No zil log devices to add"
	fi
}
#=======================================================
# Add l2arc cache devices if defined.
AddZpoolCacheVdevs() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	VDEVS=""
	if [[ ${#ZFS_CACHE_LUNS[*]} != 0 ]]
	then
		run "zpool add ${ZPOOL_NAME} -o ashift=${ZPOOL_ASHIFT} -f cache ${ZFS_CACHE_LUNS}"
	else
		msg "No l2arc cache devices to add"
	fi
}
#=======================================================
# Add all other vdevs
AddAllOtherZpoolVdevs() {
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	AddZpoolSpecialVdevs
	AddZpoolZilVdevs
	AddZpoolCacheVdevs
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

#=======================================================
# Assumes the caller passes the disk list and the topology
# in as parameters.
CreateZPool(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	ZFS_PROPS="-O atime=${ZFS_ATIME} -O recordsize=${ZFS_RECORD_SIZE} \
		   -O dnodesize=${ZFS_DNODE_SIZE} -O sync=${ZFS_SYNC} -O compression=${ZFS_COMPRESSION}"
	ZPOOL_PROPS="-o ashift=${ZPOOL_ASHIFT} -o comment=${ZPOOL_COMMENT} -o autotrim=${ZPOOL_AUTO_TRIM}"
	VDEV_SPEC="$@"
	PARMS="${ZPOOL_NAME} ${ZPOOL_PROPS} ${ZFS_PROPS} ${VDEV_SPEC[@]}"
	run "zpool create -f ${PARMS}"
	run "zpool wait -t initialize ${ZPOOL_NAME}"
	AddAllOtherZpoolVdevs
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

CreateOspreyRaidZ1_2VDEVS(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_A*)
	B_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_B*)
	ZPOOL_TOPO='raidz1'
	CreateZPool ${ZPOOL_TOPO} ${A_DISKS} ${ZPOOL_TOPO} ${B_DISKS}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

CreateOspreyRaidZ2_2VDEVS(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_A*)
	B_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_B*)
	ZPOOL_TOPO='raidz2'
	CreateZPool ${ZPOOL_TOPO} ${A_DISKS} ${ZPOOL_TOPO} ${B_DISKS}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

CreateOspreyRaidZ1_4VDEVS(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	B_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	A_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	B_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	ZPOOL_TOPO='raidz1'
	CreateZPool ${ZPOOL_TOPO} ${A_DISK1} ${ZPOOL_TOPO} ${B_DISK1} ${ZPOOL_TOPO} ${A_DISK2} ${ZPOOL_TOPO} ${B_DISK2}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
CreateOspreyRaidZ2_4VDEVS(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	B_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	A_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	B_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	ZPOOL_TOPO='raidz2'
	CreateZPool ${ZPOOL_TOPO} ${A_DISK1} ${ZPOOL_TOPO} ${B_DISK1} ${ZPOOL_TOPO} ${A_DISK2} ${ZPOOL_TOPO} ${B_DISK2}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

CreateOspreyRaidZ1_2VDEVS_5DISK (){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	B_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	A_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	B_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	ZPOOL_TOPO='raidz1'
	CreateZPool ${ZPOOL_TOPO} ${A_DISK1} ${ZPOOL_TOPO} ${B_DISK1}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
CreateOspreyRaidZ2_2VDEVS_5DISK(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	B_DISK1="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $1,$2,$3,$4,$5}')"
	A_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_A | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	B_DISK2="$(ls /dev/disk/by-partlabel/ | grep ${ZPOOL_NAME}_B | sort | tr '\n' ' ' | awk '{print $6,$7,$8,$9,$10}')"
	ZPOOL_TOPO='raidz2'
	CreateZPool ${ZPOOL_TOPO} ${A_DISK1} ${ZPOOL_TOPO} ${B_DISK1}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

CreateOspreyDraid2_8d(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_A*)
	B_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_B*)
	ZPOOL_TOPO='draid2:8d:20c:0s'
	CreateZPool ${ZPOOL_TOPO} ${A_DISKS} ${B_DISKS}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}
CreateOspreyDraid2_10d(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	#-O primarycache=metadata \
	#-O secondarycache=all \
	CreateOspreyZfsDiskConfig
	A_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_A*)
	B_DISKS=$(ls /dev/disk/by-partlabel/${ZPOOL_NAME}_B*)
	ZPOOL_TOPO='draid2:10d:20c:0s'
	CreateZPool ${ZPOOL_TOPO} ${A_DISKS} ${B_DISKS}
	printf "END: $TGT ${FUNCNAME[0]}\n"
}


CreateZfsRaidz2OnLvm(){
	printf "RUN: $TGT ${FUNCNAME[0]}\n"
	LVM_DISKS=$(ls /dev/disk/${VG_PREFIX}*/${LV_PREFIX}*)
	ZFS_PROPS="-O atime=${ZFS_ATIME} -O recordsize=${ZFS_RECORD_SIZE} -O dnodesize=${ZFS_DNODE_SIZE} -O sync=${ZFS_SYNC}"
	ZPOOL_PROPS="-o ashift=${ZPOOL_ASHIFT} -o comment=${ZPOOL_COMMENT} -o autotrim=${ZPOOL_AUTO_TRIM}"
	ZPOOL_TOPO='raidz2'
	run "zpool create -f ${ZPOOL_NAME} ${ZPOOL_PROPS} ${ZFS_PROPS} ${ZPOOL_TOPO} ${LVM_DISKS}"
	AddAllOtherZpoolVdevs
	printf "END: $TGT ${FUNCNAME[0]}\n"
}

ShowZfsMenu() {
	cmd=(dialog --keep-tite --defaultno --menu "Osprey Dual Actuator DevOps:" 22 76 16)

	options=(1 "Create Osprey ZRAID1 2Vdevs 10 disk"
		 2 "Create Osprey ZRAID2 2Vdevs 10 disk"
		 3 "Create Osprey ZRAID1 4Vdevs 10 disk"
		 4 "Create Osprey ZRAID2 4Vdevs 10 disk"
		 5 "Create Osprey ZRAID1 2Vdevs 5 disk"
		 6 "Create Osprey ZRAID2 2Vdevs 5 disk"
		 7 "Create Osprey draid2 10 disk 8d"
		 8 "Create Osprey draid2 10 disk 10d"
		 m "Main Menu"
		 x "Exit"
	 )

	while [ 1 ]
	do
		choices=$("${cmd[@]}" "${options[@]}" 2>&1>/dev/tty )
		[[ 0 != $? ]] && break
		for choice in $choices
		do
			case $choice in
			1)
				CreateOspreyRaidZ1_2VDEVS
				;;
			2)
				CreateOspreyRaidZ2_2VDEVS
				;;
			3)
				CreateOspreyRaidZ1_4VDEVS
				;;
			4)
				CreateOspreyRaidZ2_4VDEVS
				;;
			5)
				CreateOspreyRaidZ1_2VDEVS_5DISK
				;;
			6)
				CreateOspreyRaidZ2_2VDEVS_5DISK
				;;
			7)
				CreateOspreyDraid2_8d
				;;
			8)
				CreateOspreyDraid2_10d
				;;
			m)
				ShowMenuStart
				;;
			M)
				ShowMenuStart
				;;
			*)
				echo "No selection"
				exit
				;;
			esac
			printf "\n"
			read -p "Hit enter to continue ..."
		done
	done
}

ShowDiskUtils() {
	cmd=(dialog --keep-tite --defaultno --menu "Osprey Dual Actuator DevOps:" 22 76 16)

	options=(1 "ShowLunCounts"
		 2 "ShowTargetLuns"
		 3 "WipeDiskConfigs"
		 4 "CreateOspreyPartitioning"
		 m "Main Menu"
		 x "Exit"
	 )

	while [ 1 ]
	do
		choices=$("${cmd[@]}" "${options[@]}" 2>&1>/dev/tty )
		[[ 0 != $? ]] && break
		for choice in $choices
		do
			case $choice in
			1)
				ShowLunCounts
				;;
			2)
				ShowTargetLuns
				;;
			3)
				WipeDiskConfigs
				;;
			4)
				CreateOspreyPartitioning
				;;
			m)
				ShowMenuStart
				;;
			M)
				ShowMenuStart
				;;
			*)
				echo "No selection"
				exit
				;;
			esac
			printf "\n"
			read -p "Hit enter to continue ..."
		done
	done
}

ShowMenuStart() {
	cmd=(dialog --keep-tite --defaultno --menu "Osprey Dual Actuator DevOps:" 22 76 16)

	options=(1 "Show Disk Menu"
		 2 "Show ZFS Menu"
		 3 "Show LVM Menu"
		 x "Exit"
	 )

	while [ 1 ]
	do
		choices=$("${cmd[@]}" "${options[@]}" 2>&1>/dev/tty )
		[[ 0 != $? ]] && break
		for choice in $choices
		do
			case $choice in
			1)
				ShowDiskUtils
				;;
			2)
				ShowZfsMenu
				;;
			3)
				ShowLvmMenu
				;;
			*)
				echo "No selection"
				exit
				;;
			esac
			printf "\n"
			read -p "Hit enter to continue ..."
		done
	done
}

CheckForPreReqs
if [[ "${SCRIPTED_FUNCTION}"X == X ]] ; then
	ShowMenuStart
else
	#echo "Calling $SCRIPTED_FUNCTION $SCRIPTED_FUNPARAM" >&2
	$SCRIPTED_FUNCTION $SCRIPTED_FUNPARAM
fi
