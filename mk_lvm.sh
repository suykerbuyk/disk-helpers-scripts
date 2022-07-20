set -e
DRY_RUN=0
GO_SLOW=0

EVANS_DSK_PREFIX='scsi-35000c500a'
MACH2_DSK_PREFIX='scsi-36000c500a'
NYTRO_DSK_PREFIX='scsi-35000c5003'
#MACH2_STRIPE_SIZE=1024k
MACH2_STRIPE_SIZE=128k
#OSD_READ_AHEAD=1048576
OSD_READ_AHEAD=524288
OSD_SCHEDULER='noop'
DSK_PATH='/dev/disk/by-id'
LVM_VG_PREFIX='sgt_vg'
LVM_LV_PREFIX='sgt_lv'

# Simple message output
msg() {
	printf "$@\n" 
	[[ $GO_SLOW == 1 ]] && sleep 1
	return 0
}

# Run a command but first tell the user what its going to do.
run() {
	printf " $@ \n"
	[[ 1 == $DRY_RUN ]] && return 0
	eval "$@"; ret=$?
	[[ $ret == 0 ]] && return 0
   	printf " $@ - ERROR_CODE: $ret\n"
	exit $ret
}

find_drv_count() {
	find $DSK_PATH -name "$1*" | cut -c 1-38 | sort -u| wc -l
}
find_lun_count() {
	find $DSK_PATH -name "$1*" | cut -c 1-38 --complement | sort -u | wc -l
}
find_vg_count() {
	lvs | grep ${LVM_VG_PREFIX} | wc -l
}

get_drv_inventory() {
	EVANS_DRV_COUNT=$(find_drv_count "$EVANS_DSK_PREFIX")
	EVANS_LUN_COUNT=$(find_lun_count "$EVANS_DSK_PREFIX")
	MACH2_DRV_COUNT=$(find_drv_count "$MACH2_DSK_PREFIX")
	MACH2_LUN_COUNT=$(find_lun_count "$MACH2_DSK_PREFIX")
	NYTRO_DRV_COUNT=$(find_drv_count "$NYTRO_DSK_PREFIX")
	NYTRO_LUN_COUNT=$(find_lun_count "$NYTRO_DSK_PREFIX")
	TOTAL_DRV_COUNT=$((EVANS_DRV_COUNT + MACH2_DRV_COUNT + NYTRO_DRV_COUNT))
	VG_COUNT=$(find_vg_count)
}
print_drv_inventory() {
	msg "Detected $EVANS_DRV_COUNT Evans drives"
	msg "Detected $MACH2_DRV_COUNT Mach2 drives"
	msg "Detected $NYTRO_DRV_COUNT Nytro drives"
	msg "Detected $TOTAL_DRV_COUNT Total Drives"
	msg "Detected $VG_COUNT Existing Volume Groups"
}

# Simple sanity check on device parsing
do_sanity_check() {
	msg "Performing Sanity Checks"
	if [[ $EVANS_DRV_COUNT != 0 ]] && [[ $EVANS_LUN_COUNT != 1 ]]; then
		msg "ERROR: Detected Evans LUN count should 1, not $EVANS_LUN_COUNT"
		exit 1
	fi
	if [[ $MACH2_DRV_COUNT != 0 ]] && [[ $MACH2_LUN_COUNT != 2 ]]; then
		msg "ERROR: Detected Mach2 LUN count should 1, not $MACH2_LUN_COUNT"
		exit 1
	fi
}

rm_vg_devs() {
	msg "Purging volume groups"
	for VG in $( pvs | grep "${LVM_VG_PREFIX}" | awk '{print $2}' | sort -u)
	do
		PVS=$( pvs | grep $VG | awk '{ print $1 }'| tr '\n' ' ')
		msg "PVS=$PVS"
		run "   vgremove -y $VG"
		run "   pvremove -y $PVS"
	done
}

set_drv_queue() {
	if [[ -b /dev/${1} ]]
	then
		run "echo '${OSD_SCHEDULER}' >/sys/block/${1}/queue/scheduler"       # noop, deadline, cfq
		run "echo '${OSD_READ_AHEAD}' >/sys/block/${1}/queue/read_ahead_kb" # Default = 4096
	fi
}
mk_mach2_lvm() {
	msg "Creating Mach2 LVM config"
	IDX=0
	LUN_0_TAG=$(find $DSK_PATH -name "${MACH2_DSK_PREFIX}*" | cut -c 1-38 --complement | sort -u | head -1)
	LUN_1_TAG=$(find $DSK_PATH -name "${MACH2_DSK_PREFIX}*" | cut -c 1-38 --complement | sort -u | tail -1)
	for DEV in $(find $DSK_PATH -name "${MACH2_DSK_PREFIX}*" | cut -c 1-38 | sort -u ); do
		LUN_0="${DEV}${LUN_0_TAG}"
		LUN_1="${DEV}${LUN_1_TAG}"
		KDEV0="$(ls -lah $LUN_0 | awk -F '/' '{print $7}')"
		KDEV1="$(ls -lah $LUN_1 | awk -F '/' '{print $7}')"
		
		set_drv_queue "${KDEV0}"
		set_drv_queue "${KDEV1}"

		IDX_STR=$(printf '%03d' $IDX)
		VG_NAME="${LVM_VG_PREFIX}_data_${IDX_STR}"
		LV_NAME="${LVM_LV_PREFIX}_data_${IDX_STR}"
		msg "  Working on $DEV -> $KDEV0 $KDEV1"
		run "    pvcreate /dev/$KDEV0 /dev/$KDEV1"
		run "    vgcreate $VG_NAME /dev/$KDEV0 /dev/$KDEV1"
		run "    lvcreate -i ${MACH2_LUN_COUNT} -n $LV_NAME -l 100%FREE --type striped -I $MACH2_STRIPE_SIZE $VG_NAME"
		IDX=$( expr $IDX + 1 )
	done
}
mk_evans_lvm() {
	msg "Creating Evans LVM config"
	IDX=0
	for DEV in $( find ${DSK_PATH} -name "${EVANS_DSK_PREFIX}*" | cut -c 1-38 | sort -u ); do
		KDEV="/dev/$(ls -lah $DEV | awk -F '/' '{print $7}')"
		
		msg "  Working on $DEV -> $KDEV"
		run "    pvcreate ${KDEV}"

		IDX_STR=$(printf '%03d' $IDX)
		VG_NAME="${LVM_VG_PREFIX}_data_${IDX_STR}"
		LV_NAME="${LVM_LV_PREFIX}_data_${IDX_STR}"
		run "    vgcreate ${VG_NAME} ${KDEV}"
		run "    lvcreate -n ${LV_NAME} -l 100%FREE ${VG_NAME}"
		IDX=$( expr $IDX + 1 )
	done
}

mk_nytro_lvm() {
	msg "Creating Nytro LVM config"
	IDX=0
	for DEV in $( find ${DSK_PATH} -name "${NYTRO_DSK_PREFIX}*" | cut -c 1-38 | sort -u ); do
		KDEV="$(ls -lah $DEV | awk -F '/' '{print $7}')"
		msg "  Working on $DEV -> $KDEV"
		set_drv_queue "${KDEV0}"
		run "    pvcreate /dev/$KDEV"

		IDX_STR=$(printf '%03d' $IDX)
		VG_NAME="${LVM_VG_PREFIX}_db_${IDX_STR}"
		LV_NAME="${LVM_LV_PREFIX}_db_${IDX_STR}"
		run "    vgcreate ${VG_NAME} /dev/${KDEV}"
		run "    lvcreate -n ${LV_NAME}_0 -L 700G ${VG_NAME}"
		run "    lvcreate -n ${LV_NAME}_1 -L 700G ${VG_NAME}"
		run "    lvcreate -n ${LV_NAME}_2 -L 700G ${VG_NAME}"
		run "    lvcreate -n ${LV_NAME}_3 -L 700G ${VG_NAME}"
		run "    lvcreate -n ${LV_NAME}_X -L 700G ${VG_NAME}"
		IDX=$( expr $IDX + 1 )
	done
	msg "Success!"
}

get_drv_inventory
print_drv_inventory
do_sanity_check
[[ ${VG_COUNT} > 0 ]]        && rm_vg_devs
[[ ${NYTRO_DRV_COUNT} > 0 ]] && mk_nytro_lvm
[[ ${EVANS_DRV_COUNT} > 0 ]] && mk_evans_lvm
[[ ${MACH2_DRV_COUNT} > 0 ]] && mk_mach2_lvm
