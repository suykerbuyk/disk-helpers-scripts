#!/bin/bash
set -e

POOL_NAME="ZPOOL_cl-al-710cd8"

for X in 1 2 4 8 16 32
do
	REC_SIZE=$((X * 32768))
	if [ ! -d "/${POOL_NAME}/sectors/rec_${REC_SIZE}" ]
	then
		zfs create -p "${POOL_NAME}/sectors/rec_${REC_SIZE}" -o recordsize=${REC_SIZE}
	fi
done
for D in $(find /${POOL_NAME}/sectors/* -maxdepth 1 -type d)
do
	REC="$(echo $D | awk -F '_' '{print $3}')"
	echo $REC
	for F in $(seq 0 255)
	do
		TGT="${D}/sector.${F}"
		if [ ! -f ${TGT} ] ||  [ 33507390 != $(du -k $TGT | cut -f1) ] ; then
			echo "Creating $TGT"
			dd if=/dev/zero bs=1G count=32 oflag=sync of="${TGT}"
		else
			echo "Skipping ${TGT}"
		fi
	done
done
