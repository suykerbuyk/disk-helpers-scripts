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
		kdev_padded="$(printf "%-4s" $kdev)"
		vpd_pg80="$(cat $SYSFSPATH/vpd_pg80 | tr -cd '[:print:]' )"
		vendor="$(cat $SYSFSPATH/vendor | tr -d '\0')"
		vendor_trimmed="$(echo $vendor | xargs)"
		model="$(cat $SYSFSPATH/model | tr -d '\0')"
		model_trimmed="$(echo $model | xargs)"
		sas_address="$(cat $SYSFSPATH/sas_address | tr -d '\0')"
		wwid="$(cat $SYSFSPATH/wwid | tr -d '\0' | sed 's/naa.//g')"
		dev_id_paths="$(ls /dev/disk/by-id/ | grep -v part | grep $wwid |sort | tr '\n' ' ')"
		scsi_id_path="$(echo $dev_id_paths | awk '{print $1}')"
		wwn_id_path="$(echo $dev_id_paths | awk '{print $2}')"
		sg_dev="$(ls $SYSFSPATH/scsi_generic)"
		sg_dev_padded="$(printf "%-5s" $sg_dev)"
		#slot="$(cat $SYSFSPATH/enclosure_device*/slot)"
		slot="$(ls ${SYSFSPATH}/ | grep enclosure_device | awk -F ':' '{print $2}')"
		slot_padded="$(printf "%03d" $slot)"
		fw_rev="$(cat $SYSFSPATH/rev)"
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
		printf "alias ${ENC_SERIAL}_${slot_padded}_${vpd_pg80} /dev/disk/by-id/$scsi_id_path # $vendor_trimmed $model_trimmed $fw_rev_trimmed $kdev_padded $sg_dev_padded $wwn_id_path\n" | tee -a vdev_id.tmp
		#echo "    $SYSFSPATH"
	fi
done
cat vdev_id.tmp | sort  >vdev_id.conf
rm vdev_id.tmp
less vdev_id.conf
