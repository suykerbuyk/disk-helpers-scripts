#!/bin/sh

set -e

EVANS_DSK_PREFIX='scsi-35000c500a'
NYTRO_DSK_PREFIX='scsi-35000c500302'
DSK_PATH='/dev/disk/by-id'

EVANS_DRV_COUNT=$(ls $DSK_PATH/$EVANS_DSK_PREFIX* | cut -c 1-38 | sort -u| wc -l)
LUN_COUNT=$(ls $DSK_PATH/$EVANS_DSK_PREFIX* | cut -c 1-38 --complement | sort -u | wc -l )

# Simple sanity check on device parsing
if [ $LUN_COUNT != 1 ]; then
	echo "ERROR: Detected LUN count should 1, not $LUN_COUNT"
	exit 1
fi

# Device index
IDX=0
for DEV in $( ls $DSK_PATH/$EVANS_DSK_PREFIX* | cut -c 1-38 | sort -u ); do
	# echo "LUN0=$LUN_0  LUN1=$LUN_1"
        KDEV="/dev/$(ls -lah $DEV | awk -F '/' '{print $7}')"
	echo "KDEV=$KDEV"
	

        echo "pvcreate $KDEV"
        pvcreate $KDEV

        IDX_STR=$(printf '%03d' $IDX)
	VG_NAME="vg_data_$IDX_STR"
        echo " vgcreate $VG_NAME $KDEV"
        vgcreate $VG_NAME $KDEV
	
	LV_NAME="lv_$IDX_STR"
	echo "  lvcreate -n $LV_NAME -l 100%FREE $VG_NAME"
	lvcreate -n $LV_NAME -l 100%FREE $VG_NAME
        IDX=$( expr $IDX + 1 )
done

IDX=0
for DEV in $( ls $DSK_PATH/$NYTRO_DSK_PREFIX* | cut -c 1-38 | sort -u ); do
        KDEV="/dev/$(ls -lah $DEV | awk -F '/' '{print $7}')"
	echo "KDEV=$KDEV"
	

        echo "pvcreate $KDEV"
        pvcreate $KDEV

        IDX_STR=$(printf '%03d' $IDX)
	VG_NAME="vg_db_$IDX_STR"
        echo " vgcreate $VG_NAME $KDEV"
        vgcreate $VG_NAME $KDEV
	
	LV_NAME="lv_db_$IDX_STR"
	echo "  lvcreate -n ${LV_NAME}_0 -l 25%FREE $VG_NAME"
	lvcreate -n ${LV_NAME}_0 -l 700G $VG_NAME
	echo "  lvcreate -n ${LV_NAME}_1 -l 25%FREE $VG_NAME"
	lvcreate -n ${LV_NAME}_1 -l 700G $VG_NAME
	echo "  lvcreate -n ${LV_NAME}_2 -l 25%FREE $VG_NAME"
	lvcreate -n ${LV_NAME}_2 -l 700G $VG_NAME
	echo "  lvcreate -n ${LV_NAME}_3 -l 25%FREE $VG_NAME"
	lvcreate -n ${LV_NAME}_3 -l 700G $VG_NAME
	echo "  lvcreate -n ${LV_NAME}_3 -l 25%FREE $VG_NAME"
	lvcreate -n ${LV_NAME}_X -l 700G $VG_NAME
        IDX=$( expr $IDX + 1 )
done
