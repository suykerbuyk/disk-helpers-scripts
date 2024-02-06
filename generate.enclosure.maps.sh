#!/bin/bash

VDEV_FILE='vdev_id.conf'
for ENC in $(cat ${VDEV_FILE} | sed 's/alias //g' | awk -F ' ' '{print $1}' | awk -F '-' '{print $1}' | sort -u)
do
	MAP_FILE="JBOD_${ENC}.map"
	[[ -f ${MAP_FILE} ]] && $(rm "${MAP_FILE}")
	POOL_NAME="${HOSTNAME}_${ENC}"
	for DRV in $(cat ${VDEV_FILE} | sed 's/alias //g' | awk -F ' ' '{print $1}' | grep ${ENC})
	do
		LINE="/dev/disk/by-vdev/${DRV}"
		SLOT=$(echo ${LINE} | awk -F '-' '{print $3}' | sed 's/^0*//g')
		if [ "X${SLOT}" == "X" ] ; then SLOT='0'; fi
		if [ "$(($SLOT))" -eq 80 ]; then echo "FOund 80"; fi
		echo "${SLOT} ${LINE} \\" | tee -a "JBOD_${ENC}.map"
	done
done
