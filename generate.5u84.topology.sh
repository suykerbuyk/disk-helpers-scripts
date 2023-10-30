#!/bin/bash

#while IFS= read -r line
#do
#	if echo $line | grep -q "ST18000NM004J"
#	then
#		printf '%s ' "$line"
#		KDEV=$(echo $line | awk -F ' '  '{print $3}' | awk -F '/' '{print $3}')
#		echo "KDEV=$KDEV"
#		DEVPATH=$(ls -lah /dev/disk/by-id/scsi-* | grep -v part | grep -e "\.\./\.\./$KDEV\t" | awk -F ' ' '{print $9}' ) 
#		printf '%s %s\n' "$KDEV" "$DEVPATH"
#	else
#		printf '%s\n' "$line"
#	fi
#done <5u84.topology.txt

DSK_PAT='scsi-35000c500d'

TMPFILE="${PWD}/${0##*/}-$$-$(date --iso-8601).tmp"
trap 'rm -rf "$TMPFILE"; exit' ERR EXIT SIGINT QUIT # HUP INT TERM

SlotDeviceMapping() {
	find /sys/class/enclosure/*/*/device/block/ -maxdepth 1 -mindepth 1 >$TMPFILE
	for DSK_UUID in $(find  -L /dev/disk/by-id/ -xtype l -iname "${DSK_PAT}*" ! -name "*part*" -exec printf " {} " \; )
	do
		KDEV=$(realpath $DSK_UUID | sed 's:/dev/::g')
		KDEV_ALIGNED=$(printf %04s $KDEV)
		ENC_DSK_PATH=$(cat $TMPFILE | grep "${KDEV}"'$')
		ENC_PCI_ID=$( cd "$ENC_DSK_PATH/../../.."; dirname $PWD | sed 's|/sys/class/enclosure/||g');
		ENC_PCI_ID_ALIGNED=$(printf %010s $ENC_PCI_ID)
		ENC_DSK_SLOT=$( cd "$ENC_DSK_PATH/../../"; dirname $PWD | sed 's|/sys/class/enclosure/.*/||g')
		ENC_DSK_SLOT_ALIGNED=$(printf %02d $ENC_DSK_SLOT)
		ENC_VENDOR=$(cat /sys/class/enclosure/${ENC_PCI_ID}/device/vendor)
		ENC_MODEL=$(cat /sys/class/enclosure/${ENC_PCI_ID}/device/model)
		#ENC_SERIAL="$(tr -d '\0\|\r' </sys/class/enclosure/${ENC_PCI_ID}/device/vpd_pg80)"
		ENC_SERIAL="$(cat /sys/class/enclosure/${ENC_PCI_ID}/device/vpd_pg80 | cut -b 5-19)"
		echo "$ENC_VENDOR $ENC_MODEL $ENC_SERIAL $ENC_PCI_ID_ALIGNED $ENC_DSK_SLOT_ALIGNED $KDEV_ALIGNED $DSK_UUID"
	done | sort
}

LAST_SERIAL=""
VDEV=0
rm VDEV_DISKS.map 5u84-disk.map | true
while IFS= read -r LINE
do
	MAKE=$(echo $LINE | awk '{print $1}')
	MODEL=$(echo $LINE | awk '{print $2}')
	SERIAL=$(echo $LINE | awk '{print $3}')
	SLOT=$(echo $LINE | awk '{print $5}')
	KDEV=$(echo $LINE | awk '{print $6}')
	DSK=$(echo $LINE | awk '{print $7}')
	ENC="${MAKE}-${MODEL}-${SERIAL}"
	#echo "$ENC $DSK \ # SLOT=$SLOT KDEV=$KDEV" | tee -a 5u84-disk.map
	#echo "$DSK \\ # SERIAL=$SERIAL SLOT=${SLOT} KDEV=${KDEV}" >>"VDEV_DISK_MAP_${ENC}.txt"
	if [ "$SERIAL" != "$LAST_SERIAL" ] ; then
		printf "\n" >>VDEV_DISKS.map 
		printf "\n" tee -a 5u84-disk.map
		LAST_SERIAL="$SERIAL"
	fi
	printf '%s\n' "$LINE" | tee -a 5u84-disk.map
	echo "$DSK \\ # SERIAL=$SERIAL SLOT=${SLOT} KDEV=${KDEV}" >>"VDEV_DISKS.map"
done < <(SlotDeviceMapping)
