#!/bin/sh

set -e

DSK_PREFIX='wwn-0x6000'
DSK_PATH='/dev/disk/by-id'

DRV_COUNT=$(ls $DSK_PATH/$DSK_PREFIX* | cut -c 1-38 | sort -u| wc -l)
LUN_COUNT=$(ls $DSK_PATH/$DSK_PREFIX* | cut -c 1-38 --complement | sort -u | wc -l )

# Simple sanity check on device parsing
if [ $LUN_COUNT != 2 ]; then
	echo "ERROR: Detected LUN count should be 2, not $LUN_COUNT"
	exit 1
fi

# Figure out how LUNS are marked.
LUN_0_TAG=$(ls /dev/disk/by-id/wwn-0x6000*  | cut -c 1-38 --complement | sort -u | head -1)
LUN_1_TAG=$(ls /dev/disk/by-id/wwn-0x6000*  | cut -c 1-38 --complement | sort -u | tail -1)

# Device index
IDX=0
for DEV in $( ls $DSK_PATH/$DSK_PREFIX* | cut -c 1-38 | sort -u ); do
	LUN_0="$DEV$LUN_0_TAG"
	LUN_1="$DEV$LUN_1_TAG"
	# echo "LUN0=$LUN_0  LUN1=$LUN_1"
        KDEV0="/dev/$(ls -lah $LUN_0 | awk -F '/' '{print $7}')"
        KDEV1="/dev/$(ls -lah $LUN_1 | awk -F '/' '{print $7}')"
	# echo "LUN0=$KDEV0  LUN1=$KDEV1"
	

        echo "pvcreate $KDEV0 $KDEV1"
        pvcreate $KDEV0 $KDEV1

        IDX_STR=$(printf '%03d' $IDX)
	VG_NAME="vg_$IDX_STR"
        echo " vgcreate $VG_NAME $KDEV0 $KDEV1"
        vgcreate $VG_NAME $KDEV0 $KDEV1
	
	LV_NAME="lv_$IDX_STR"
	echo "  lvcreate -i $LUN_COUNT -n $LV_NAME -l 100%FREE $VG_NAME"
	lvcreate -i $LUN_COUNT -n $LV_NAME -l 100%FREE $VG_NAME
        IDX=$( expr $IDX + 1 )
done

