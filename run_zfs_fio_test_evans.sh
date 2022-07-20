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
	for DISK in $(ls /dev/disk/by-id/wwn-0x5000c500ae* | grep -v part )
	do
		for PART in $(fdisk -l $DISK 2>/dev/null | grep Solaris | sort -r | awk '{print $1}')
		do 
			parted -s $DISK rm $PART
		done
	done
}

evans_zfs_raidz1() {
zpool create $POOL \
	raidz1 wwn-0x5000c500ae9ef1ff \
	       wwn-0x5000c500ae5c9e03 \
	       wwn-0x5000c500ae7ec25b \
	       wwn-0x5000c500ae6878e3 \
	raidz1 wwn-0x5000c500ae2c702b \
	       wwn-0x5000c500ae7ec3bf \
	       wwn-0x5000c500ae30dff3 \
	       wwn-0x5000c500ae29a2ef \
	raidz1 wwn-0x5000c500ae632a83 \
	       wwn-0x5000c500ae6638d3 \
	       wwn-0x5000c500ae27ae17 \
	       wwn-0x5000c500ae32df5b \
	       -o feature@lz4_compress=disabled
}

evans_zfs_raidz2() {
	zpool create $POOL \
	raidz2 wwn-0x5000c500ae9ef1ff \
	       wwn-0x5000c500ae5c9e03 \
	       wwn-0x5000c500ae7ec25b \
	       wwn-0x5000c500ae6878e3 \
	raidz2 wwn-0x5000c500ae2c702b \
	       wwn-0x5000c500ae7ec3bf \
	       wwn-0x5000c500ae30dff3 \
	       wwn-0x5000c500ae29a2ef \
	raidz2 wwn-0x5000c500ae632a83 \
	       wwn-0x5000c500ae6638d3 \
	       wwn-0x5000c500ae27ae17 \
	       wwn-0x5000c500ae32df5b \
	       -o feature@lz4_compress=disabled
}

evans_zfs_zmirror() {
	zpool create tank \
	mirror wwn-0x5000c500ae9ef1ff \
	       wwn-0x5000c500ae5c9e03 \
	mirror wwn-0x5000c500ae7ec25b \
	       wwn-0x5000c500ae6878e3 \
	mirror wwn-0x5000c500ae2c702b \
	       wwn-0x5000c500ae7ec3bf \
	mirror wwn-0x5000c500ae30dff3 \
	       wwn-0x5000c500ae29a2ef \
	mirror wwn-0x5000c500ae632a83 \
	       wwn-0x5000c500ae6638d3 \
	mirror wwn-0x5000c500ae27ae17 \
	       wwn-0x5000c500ae32df5b \
	       -o feature@lz4_compress=disabled
}

# cache  wwn-0x5000c500302dc95b \
# log    wwn-0x5000c500302d4333
if [ ! -d log ]; then
	mkdir log
fi

for config in 'evans_zfs_raidz1' 'evans_zfs_raidz2' 'evans_zfs_zmirror' 
do
	rm_zfs_parts
	$config
#	for JOBS in 1 4 8 16 32; do
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


