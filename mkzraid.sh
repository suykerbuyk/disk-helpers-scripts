#!/bin/bash

ZPOOL_NAME="DESTOR"
VDEV_DSK_CNT=10
LUN_PATTERN="/dev/disk/by-id/wwn-0x5000c500c"
ZRAID_VDEV_TYPE="raidz2"
PROVISION_SCRIPT="$PWD/create_zraid.sh"

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

mkarray() {
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
#wipe_zfs
mkarray
chmod +x "${PROVISION_SCRIPT}"
