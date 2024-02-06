#realpath /sys/class/block/sdlg
#realpath /sys/devices/pci0000:40/0000:40:08.2/0000:43:00.0/ata1/host1/target1:0:0/1:0:0:0/block/sdlg/device
#realpath /sys/devices/pci0000:40/0000:40:08.2/0000:43:00.0/ata1/host1/target1:0:0/1:0:0:0/scsi_device/1:0:0:0/device
#
# ls $(realpath $(realpath /sys/class/block/sdak)/device) -lah
#
[ -f ./vdev_id.tmp ] && rm ./vdev_id.tmp
for KDEV in $(find /sys/class/block -maxdepth 1 -not -name '*[0-9]')
do
	SYSFSPATH="$(realpath $(realpath $(realpath $KDEV))/device)"
	kdev=$(basename $KDEV)
	if [ -d $SYSFSPATH/scsi_generic ]\
		&& [ -f $SYSFSPATH/vpd_pg80 ] \
		&& [ -f $SYSFSPATH/sas_address ] ; then
		kdev_padded="$(printf "%-5s" $kdev)"
		vpd_pg80="$(cat $SYSFSPATH/vpd_pg80 | tr -cd '[:print:]' )"
		vendor="$(cat $SYSFSPATH/vendor | tr -cd '[:print:]')"
		vendor_trimmed="$(echo $vendor | xargs)"
		model="$(cat $SYSFSPATH/model | tr -cd '[:print:]')"
		model_trimmed="$(echo $model | xargs)"
		sas_address="$(cat $SYSFSPATH/sas_address | tr -cd '[:print:]')"
		wwid="$(cat $SYSFSPATH/wwid | tr -cd '[:print:]' | sed 's/naa.//g')"
		dev_id_paths="$(ls /dev/disk/by-id/ | grep -v part | grep $wwid |sort | tr '\n' ' ')"
		scsi_id_path="$(echo $dev_id_paths | awk '{print $1}' | xargs )"
		wwn_id_path="$(echo $dev_id_paths  | awk '{print $2}' | xargs )"
		sg_dev="$(ls $SYSFSPATH/scsi_generic)"
		sg_dev_padded="$(printf "% 5s" $sg_dev)"
		slot="$(ls ${SYSFSPATH}/ | grep enclosure_device | awk -F ':' '{print $2}' | tr -cd '[:print:]')"
		slot_padded="$(printf "%03d" $slot | tr -cd '[:print:]')"
		fw_rev="$(cat $SYSFSPATH/rev | tr -cd '[:print:]')"
		fw_rev_trimmed="$(echo $fw_rev | xargs)"
		ENC_SERIAL=""
		for ENC_PATH_VPD_PG80 in $(find /sys/class/enclosure/*/$slot/device/vpd_pg80)
		do
			T=$(cat $ENC_PATH_VPD_PG80 | tr -cd '[:print:]')
			#echo "Looking for: $vpd_pg80   Found: $T"
			if [ "$vpd_pg80" == "$T" ]
			then
				TARGET_ENC_DEVICE="$(dirname $(dirname $(dirname $ENC_PATH_VPD_PG80)))"
				ENC_SERIAL=$(cat $TARGET_ENC_DEVICE/device/vpd_pg80 | tr -cd '[:print:]' | xargs)
				break
			fi
		done
		if [ "X" != "X${ENC_SERIAL}" ] ; then
			VDEV_CONF_LINE="alias ${ENC_SERIAL}-${slot_padded}-${vpd_pg80} /dev/disk/by-id/$scsi_id_path # $vendor_trimmed $model_trimmed $fw_rev_trimmed ${kdev_padded} $sg_dev_padded $wwn_id_path"
			printf "${VDEV_CONF_LINE}\n"| tee -a vdev_id.tmp
			ENC_MAP_LINE="${slot_padded} ${vpd_pg80} ${vendor} ${model} ${fw_rev_trimmed} /dev/disk/by-id/${scsi_id_path} /dev/disk/by-id/${wwn_id_path} ${kdev_padded} ${sg_dev_padded}"
			printf "${ENC_MAP_LINE}\n" >>${ENC_SERIAL}_enclosure.tmp
			#echo "    $SYSFSPATH"
		fi
	fi
done
BASE_ENC_MAP_NAME="enclosure_$(date --iso-8601).map"
TMP_ENC_MAPS="$(ls *_enclosure.tmp | sort | tr '\n' ' ')"
ENCLOSURE_LIST="$(echo $TMP_ENC_MAPS | sed 's/_enclosure.tmp//g')"
for ENC in $ENCLOSUE_LIST
do
	if [ -f "${ENC}_${BASE_ENC_NAME}" ]
	then
		rm "${ENC}_${BASE_ENC_NAME}"
	fi
done
for TMP_ENC_FILE in $TMP_ENC_MAPS
do
	ENC="$(echo ${TMP_ENC_FILE} | awk -F '_' '{print $1}')"
	cat "${TMP_ENC_FILE}" | sort -u >"${ENC}_${BASE_ENC_MAP_NAME}"
	rm ${TMP_ENC_FILE}
done
cat vdev_id.tmp | sort  >vdev_id.conf
rm vdev_id.tmp
#less vdev_id.conf

