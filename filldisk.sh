#!/bin/sh


# Setup
# mkdir /mnt/corvault
# mount /dev/mapper/3600c0ff00052075ba61e8d6101000000 /mnt/corvault/
# mkdir /mnt/ramdisk
# mount -t tmpfs -o size=13G testdata /mnt/ramdisk/
OUTDIR=/mnt/corvault
SRCDIR=/mnt/ramdisk

prep_test_data(){
	for X in $(seq 0 9)
	do
		FNAME=$(printf %03d $X)
		FNAME="RAND${FNAME}.tst"
		echo $FNAME
		dd if=/dev/urandom of=${SRCDIR}/${FNAME} bs=1M count=1024 oflag=sync &
	done
	wait
}

copy_test_data(){
	for X in $(seq 0 99)
	do
		DIR1=$(printf %03d $X)
		for Y in $(seq 0 99)
		do
			DIR2=$(printf %03d $Y)
			for Z in $(seq 0 99)
			do
				DIR3=$(printf %03d $Z)
				DEST="${OUTDIR}/${DIR1}/${DIR2}/${DIR3}"
				mkdir -p "${DEST}"
				for F in $(ls $SRCDIR)
				do
					echo dd if=$SRCDIR/$F of=$DEST/$F bs=1M oflag=sync
					dd if=$SRCDIR/$F of=$DEST/$F bs=1M &
				done
				wait
				sync
			done
		done
	done
}
copy_test_data

