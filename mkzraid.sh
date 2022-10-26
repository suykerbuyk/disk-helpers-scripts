#!/bin/bash

ZPOOL_NAME="DESTOR"
VDEV_DSK_CNT=12
EVANS_WWN_BASE='wwn-0x5000c500c'
MACH2_WWN_BASE='wwn-0x6000c500a'
TATSU_WWN_BASE='wwn-0x5000c5009'
CRVLT_WWN_BASE='wwn-0x600c0ff00'
LUN_PATTERN="/dev/disk/by-id/${CRVLT_WWN_BASE}*"
ZRAID_VDEV_TYPE="raidz2"
PROVISION_SCRIPT="$PWD/provision_zfs.sh"

EVANS_LUN_CNT=$(ls /dev/disk/by-id/${EVANS_WWN_BASE}* | grep -v part| wc -l)
MACH2_LUN_CNT=$(ls /dev/disk/by-id/${MACH2_WWN_BASE}* | grep -v part| wc -l)
TATSU_LUN_CNT=$(ls /dev/disk/by-id/${TATSU_WWN_BASE}* | grep -v part| wc -l)
CRVLT_LUN_CNT=$(ls /dev/disk/by-id/${CRVLT_WWN_BASE}* | grep -v part| wc -l)

echo "EVANS_LUN_CNT=${EVANS_LUN_CNT}"
echo "MACH2_LUN_CNT=${MACH2_LUN_CNT}"
echo "TATSU_LUN_CNT=${TATSU_LUN_CNT}"
echo "CRVLT_LUN_CNT=${CRVLT_LUN_CNT}"
wipe_zfs() {
	for P in $(zpool list | grep "$ZPOOL_NAME" | awk '{print $1}')
	do
		umount "/${P}"
		echo "zpool destroy $P"
		zpool destroy "${P}"
	done
	# clear out the primary ZFS partion
	for X in $(ls ${LUN_PATTERN}* | grep part1)
	do
		zpool labelclear -f ${X} ; wipefs -a ${X} >/dev/null &
	done
	echo "Waiting for wipfs on part1"
	wait

	# clear out the residual end of disk partition
	for X in $(ls ${LUN_PATTERN}* | grep part9)
	do
		wipefs -a ${X} >/dev/null &
	done
	echo "Waiting for wipfs on part9"
	wait

	# Finally, wipe out the GPT partions.
	for X in $(ls ${LUN_PATTERN}* | grep -v part)
	do
		sgdisk -Z ${X} >/dev/null &
	done
	echo "Waiting for sgdisk"
	wait
	echo "Calling partprobe"
	partprobe
}

mkraidz2_script() {
	declare -A dsk_array
	ROW=""
	CNTR=1
	SPARES=""
	GRP_CNTR=0
	for X in $(ls ${LUN_PATTERN}*) ; do
		ROW="${ROW} ${X}"
		if [[ $(expr $CNTR % $VDEV_DSK_CNT) == "0"  ]]; then
			dsk_array[$GRP_CNTR]="${ROW}"
			GRP_CNTR=$((GRP_CNTR+1))
			ROW=""
			SPARES=""
		else
			SPARES="$SPARES $X"
		fi
		CNTR=$(( CNTR + 1))
	done
	printf "#!/bin/bash\n\n" | tee "${PROVISION_SCRIPT}"
	#printf "zpool create %s\\" ${ZPOOL_NAME} | tee -a "${PROVISION_SCRIPT}"
	echo "zpool create  ${ZPOOL_NAME}\\" | tee -a "${PROVISION_SCRIPT}"
	echo
	VDEV_CNTR="$GRP_CNTR"
	for SET in $(seq 0 $((VDEV_CNTR - 1 )) ) ; do
		#printf "   %s %s\\" "${ZRAID_VDEV_TYPE}" "${dsk_array[$SET]}" | tee -a "${PROVISION_SCRIPT}"
		echo "   ${ZRAID_VDEV_TYPE} ${dsk_array[$SET]}\\" | tee -a "${PROVISION_SCRIPT}"
		echo
	done
	printf "   spare %s\n" "$SPARES" | tee -a "${PROVISION_SCRIPT}"
}
wipe_zfs
mkraidz2_script
chmod +x "${PROVISION_SCRIPT}"
