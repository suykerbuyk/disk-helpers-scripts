#!/bin/env bash
set -e


build_vdev_id_conf() {
	echo "Building temporary map of enclosure information"
	[ -f ./vdev_id.tmp ] && rm ./vdev_id.tmp
	for KDEV in $(find /sys/class/block -maxdepth 1 -not -name '*[0-9]')
	do
		SYSFSPATH="$(realpath $(realpath $(realpath $KDEV))/device)"
		kdev=$(basename $KDEV)
		printf "$kdev    \r"
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
			printf "."
			if [ "X" != "X${ENC_SERIAL}" ] ; then
				VDEV_CONF_LINE="alias ${ENC_SERIAL}-${slot_padded}-${vpd_pg80} /dev/disk/by-id/$scsi_id_path # $vendor_trimmed $model_trimmed $fw_rev_trimmed ${kdev_padded} $sg_dev_padded $wwn_id_path"
				printf "${VDEV_CONF_LINE}\n" >>vdev_id.tmp
				ENC_MAP_LINE="${slot_padded} ${vpd_pg80} ${vendor} ${model} ${fw_rev_trimmed} /dev/disk/by-id/${scsi_id_path} /dev/disk/by-id/${wwn_id_path} ${kdev_padded} ${sg_dev_padded}"
				printf "${ENC_MAP_LINE}\n" >>${ENC_SERIAL}_enclosure.tmp
				#echo "    $SYSFSPATH"
			fi
		fi
	done
	printf "         \n"
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
}

build_vdev_maps() {
	DISKS_PER_VDEV=10
	MAX_VDEVS=8
	VDEV_FILE='vdev_id.conf'
	
	#Any disks beyond MAX_VDEVS will be used as spares.
	MAX_VDEV_DISKS=$((MAX_VDEVS * DISKS_PER_VDEV))

	echo "DISKS_PER_VDEV = $DISKS_PER_VDEV"
	echo "MAX_VDEVS = $MAX_VDEVS"
	echo "MAX_VDEV_DISKS = $MAX_VDEV_DISKS"

	ENCLOSURE_LIST=""
	VDEV_LIST=""

	echo "Generating vdev_id.conf file"

	for ENC in $(cat ${VDEV_FILE} | sed 's/alias //g' | awk -F ' ' '{print $1}' | awk -F '-' '{print $1}' | sort -u)
	do
		if [ -z "$ENCLOSURE_LIST" ] ; then
			ENCLOSURE_LIST="$ENC"
		else
			ENCLOSURE_LIST="$ENCLOSURE_LIST $ENC"
		fi
		MAP_FILE="JBOD_${ENC}.map"
		VDEV=0
		[[ -f ${MAP_FILE} ]] && $(rm "${MAP_FILE}")
		POOL_NAME="${HOSTNAME}_${ENC}"
		for DRV in $(cat ${VDEV_FILE} | sed 's/alias //g' | awk -F ' ' '{print $1}' | grep ${ENC})
		do
			LINE="/dev/disk/by-vdev/${DRV}"
			SLOT=$(echo ${LINE} | awk -F '-' '{print $3}' | sed 's/^0*//g')
			VDEV_PADDED="$(printf %02d $VDEV)"
			if [ "X${SLOT}" == "X" ] ; then SLOT='0'; fi
			if [ $((SLOT % DISKS_PER_VDEV)) == 0 ] ; then
				[ $SLOT  != 0 ] && printf "\" \n" >>"JBOD_${ENC}.map"
				if [ $SLOT == $MAX_VDEV_DISKS ] ; then
					printf "${ENC}_SPARES=\" \n" >>"JBOD_${ENC}.map"
				else
					VDEV_NAME="${ENC}_VDEV_${VDEV_PADDED}"
					printf "${VDEV_NAME}=\" \n" >>"JBOD_${ENC}.map"
					if [ -z "$VDEV_LIST" ] ; then
						VDEV_LIST="$VDEV_NAME"
					else
						VDEV_LIST="$VDEV_LIST $VDEV_NAME"
					fi
					VDEV=$((VDEV+1))
				fi
			else
				printf " \n" >>"JBOD_${ENC}.map"
			fi
			printf "${LINE}" >>"JBOD_${ENC}.map"
		done
		printf "\"\n" >>"JBOD_${ENC}.map"
	done
	printf "ENCLOSURE_LIST='${ENCLOSURE_LIST}'\n" >>"JBOD_${ENC}.map"
	printf "VDEV_LIST='${VDEV_LIST}'\n" >>"JBOD_${ENC}.map"
}
create_raidz2_scripts(){
	echo "Generating mk_zraid2.sh script"
	OFILE="mk_raidz2.sh"
	[ -f "${OFILE}" ] && rm "${OFILE}"
	for MAP in $(ls JBOD_*.map)
	do
		cat ${MAP} >>"${OFILE}"
		for VDEV in $(cat $MAP | grep -E VDEV\|SPARE | grep -v LIST | awk -F '=' '{print $1}')
	       	do
			echo -n "raidz2 \$$VDEV " >>"${OFILE}"
	       	done
		echo >>"${OFILE}"
       	done 
	cat "${OFILE}" | grep -v raidz2  >"${OFILE}.tmp"
	cat "${OFILE}" | grep    raidz2 >>"${OFILE}.tmp"
	mv "${OFILE}.tmp" ${OFILE}
	chmod +x "${OFILE}"
}
create_draid_scripts(){
	echo "Generating mk_draid.sh script"
	[ -f 'mk_draid.sh' ] && rm mk_draid.sh
	ENCLOSURES="$(cat vdev_id.conf | awk '{print $2}' | awk -F '-' '{print $1}  ' | sort -u | tr '\n' ' ')"
	for ENC in $ENCLOSURES
	do
		DISKS="$(cat vdev_id.conf | grep ${ENC} | awk '{print $2}' | sort -u | tr '\n' ' ')"
		printf "raidz2:8d:84c "\"
		for DSK in $DISKS
		do
			printf " \\ \n"
			printf "/dev/disk/by-vdev/$DSK"
		done
		printf "\"\n"
	done >>mk_draid.sh
}
build_vdev_id_conf
build_vdev_maps
create_raidz2_scripts
create_draid_scripts
