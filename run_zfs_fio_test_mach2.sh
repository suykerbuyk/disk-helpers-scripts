#!/bin/sh

set -e

POOL=tank
rm_zfs_parts() {
        grep -qs "$POOL" /proc/mounts \
          && echo "Destroying previous pool \"$POOL\"" \
          && zpool destroy $POOL 
	for x in $(ls /dev/disk/by-id/ | grep wwn-0x6000 | grep 0001000000000000 | grep -v part) 
	do
		LUN1="/dev/disk/by-id/$x"
		LUN0="$(echo $LUN1 | sed 's/0001000000000000/0000000000000000/g')"
		for DISK in $LUN0 $LUN1
		do
			for PART in $(fdisk -l $DISK 2>/dev/null | grep Solaris | sort -r | awk '{print $1}')
			do 
				# echo "parted $DISK rm $PART"
				parted -s $DISK rm $PART
			done
		done
		#echo "parted $LUN1 rm 1 rm 9"
	done
}

mach2_zfs_raidz1() {
zpool create $POOL \
	raidz1 wwn-0x6000c500ae35ff4b0000000000000000 \
	       wwn-0x6000c500ae33d20f0000000000000000 \
	       wwn-0x6000c500ae33d20f0001000000000000 \
	       wwn-0x6000c500ae6b2ef30000000000000000 \
	raidz1 wwn-0x6000c500ae33a4b30000000000000000 \
	       wwn-0x6000c500ae6b2d8f0000000000000000 \
	       wwn-0x6000c500ae38ae830000000000000000 \
	       wwn-0x6000c500ae2eff9f0000000000000000 \
	raidz1 wwn-0x6000c500ae2f00bf0000000000000000 \
	       wwn-0x6000c500ae6b2a270000000000000000 \
	       wwn-0x6000c500ae178ae70000000000000000 \
	       wwn-0x6000c500ae33b91f0000000000000000 \
	raidz1 wwn-0x6000c500ae35b3030000000000000000 \
	       wwn-0x6000c500ae35ff4b0001000000000000 \
	       wwn-0x6000c500ae6b2ef30001000000000000 \
	       wwn-0x6000c500ae33a4b30001000000000000 \
	raidz1 wwn-0x6000c500ae6b2d8f0001000000000000 \
	       wwn-0x6000c500ae38ae830001000000000000 \
	       wwn-0x6000c500ae2eff9f0001000000000000 \
	       wwn-0x6000c500ae2f00bf0001000000000000 \
	raidz1 wwn-0x6000c500ae6b2a270001000000000000 \
	       wwn-0x6000c500ae178ae70001000000000000 \
	       wwn-0x6000c500ae33b91f0001000000000000 \
	       wwn-0x6000c500ae35b3030001000000000000 \
	       -o feature@lz4_compress=disabled
}

mach2_zfs_raidz2() {
	zpool create $POOL \
	raidz2 wwn-0x6000c500ae35ff4b0000000000000000 \
	       wwn-0x6000c500ae33d20f0000000000000000 \
	       wwn-0x6000c500ae33d20f0001000000000000 \
	       wwn-0x6000c500ae6b2ef30000000000000000 \
	raidz2 wwn-0x6000c500ae33a4b30000000000000000 \
	       wwn-0x6000c500ae6b2d8f0000000000000000 \
	       wwn-0x6000c500ae38ae830000000000000000 \
	       wwn-0x6000c500ae2eff9f0000000000000000 \
	raidz2 wwn-0x6000c500ae2f00bf0000000000000000 \
	       wwn-0x6000c500ae6b2a270000000000000000 \
	       wwn-0x6000c500ae178ae70000000000000000 \
	       wwn-0x6000c500ae33b91f0000000000000000 \
	raidz2 wwn-0x6000c500ae35b3030000000000000000 \
	       wwn-0x6000c500ae35ff4b0001000000000000 \
	       wwn-0x6000c500ae6b2ef30001000000000000 \
	       wwn-0x6000c500ae33a4b30001000000000000 \
	raidz2 wwn-0x6000c500ae6b2d8f0001000000000000 \
	       wwn-0x6000c500ae38ae830001000000000000 \
	       wwn-0x6000c500ae2eff9f0001000000000000 \
	       wwn-0x6000c500ae2f00bf0001000000000000 \
	raidz2 wwn-0x6000c500ae6b2a270001000000000000 \
	       wwn-0x6000c500ae178ae70001000000000000 \
	       wwn-0x6000c500ae33b91f0001000000000000 \
	       wwn-0x6000c500ae35b3030001000000000000 \
	       -o feature@lz4_compress=disabled
}

mach2_zfs_zmirror() {
	zpool create tank \
	mirror wwn-0x6000c500ae35ff4b0000000000000000 \
	       wwn-0x6000c500ae33d20f0000000000000000 \
	mirror wwn-0x6000c500ae33d20f0001000000000000 \
	       wwn-0x6000c500ae6b2ef30000000000000000 \
	mirror wwn-0x6000c500ae33a4b30000000000000000 \
	       wwn-0x6000c500ae6b2d8f0000000000000000 \
	mirror wwn-0x6000c500ae38ae830000000000000000 \
	       wwn-0x6000c500ae2eff9f0000000000000000 \
	mirror wwn-0x6000c500ae2f00bf0000000000000000 \
	       wwn-0x6000c500ae6b2a270000000000000000 \
	mirror wwn-0x6000c500ae178ae70000000000000000 \
	       wwn-0x6000c500ae33b91f0000000000000000 \
	mirror wwn-0x6000c500ae35b3030000000000000000 \
	       wwn-0x6000c500ae35ff4b0001000000000000 \
	mirror wwn-0x6000c500ae6b2ef30001000000000000 \
	       wwn-0x6000c500ae33a4b30001000000000000 \
	mirror wwn-0x6000c500ae6b2d8f0001000000000000 \
	       wwn-0x6000c500ae38ae830001000000000000 \
	mirror wwn-0x6000c500ae2eff9f0001000000000000 \
	       wwn-0x6000c500ae2f00bf0001000000000000 \
	mirror wwn-0x6000c500ae6b2a270001000000000000 \
	       wwn-0x6000c500ae178ae70001000000000000 \
	mirror wwn-0x6000c500ae33b91f0001000000000000 \
	       wwn-0x6000c500ae35b3030001000000000000 \
	       -o feature@lz4_compress=disabled
}

# cache  wwn-0x5000c500302dc95b \
# log    wwn-0x5000c500302d4333
do_test() {
	if [ ! -d log ]; then
		mkdir log
	fi
	for config in 'mach2_zfs_raidz1' 'mach2_zfs_raidz2' 'mach2_zfs_zmirror' 
	do
		rm_zfs_parts
		$config
		for JOBS in 1 2 4 8; do
			for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
				for BLK in 4k 8k 16k 32k 64k 128k 256k 512k 1024k 2048k; do
					BLKNAME=$(echo "00000$BLK" | grep -o '.....$')
					echo "Running $PAT with block size $BLK against zfs pool \"$POOL\" with $JOBS jobs"
					# fio --name="${config}-$PAT-$BLK" \
					fio --directory=/$POOL/ \
					    --name="${config}" \
					    --rw=$PAT \
					    --group_reporting=1 \
					    --bs=$BLK \
					    --direct=1 \
					    --numjobs=$JOBS \
					    --time_based=1 \
					    --runtime=180 \
					    --iodepth=32 \
					    --ioengine=libaio \
					    --size=64G \
					    --output-format=json | tee "$PWD/log/${config}-$PAT-$BLKNAME-$JOBS.fio.json"
					echo "Completed"
				done
			done
		done
	done
}
 # fio fio/saturate.fio | tee log/saturate-zfs1-no-cache-8files-bs128k.log
 # fio fio/saturate.fio | tee log/saturate-zfs2-no-cache-8files-bs128k.log
 # fio fio/saturate.fio | tee log/saturate-zfs.mirror-no-cache-8files-bs128k.log
do_test
