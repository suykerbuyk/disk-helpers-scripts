#!/bin/sh

# lsblk -JO | jq -r '."blockdevices"[] | select( .group == "disk" and .vendor == "SEAGATE ")| ."model" + " " + ."path" + " " + ."vendor" + " " + .serial + " " +  ."size" + " "+ ."wwn" ' | grep ST1600
#lsblk -JO | jq -r '."blockdevices"[] | select( .group == "disk" and .vendor == "SEAGATE ")| ."model" + " " + ."path" + " " + ."vendor" + " " + .serial + " " +  ."size" + " "+ ."wwn" '|sort

DEVS=""
DEVCNT=0
POOL=minio

for X in $(lsblk -JO | jq -r '."blockdevices"[] | select( .group == "disk" and .vendor == "SEAGATE " and .size =="14.6T")|"wwn-"+ ."wwn"')
do
	DEVS="${DEVS} ${X}"
	DEVCNT=$((DEVCNT+1))
done
#echo "DEVCNT=$DEVCNT"
#echo $DEVS

draid40() {
	zpool create $POOL draid2:10d:${DEVCNT}c:4s ${DEVS} \
		cache wwn-0x5000c500302f88cb wwn-0x5000c500302dc95b wwn-0x5000c500302dc907 wwn-0x5000c500302d439b \
		log mirror  wwn-0x5000c500a187d0d7 wwn-0x5000c500a187d2b7
	zfs set sync=disabled $POOL

}

raidz2_4stripe() {
	VDEV1="$(echo ${DEVS} | cut -d " " -f 1-10)"
	VDEV2="$(echo ${DEVS} | cut -d " " -f 11-20)"
	VDEV3="$(echo ${DEVS} | cut -d " " -f 21-30)"
	VDEV4="$(echo ${DEVS} | cut -d " " -f 31-40)"
	zpool create $POOL \
		raidz2 $VDEV1 \
		raidz2 $VDEV2 \
		raidz2 $VDEV3 \
		raidz2 $VDEV4 \
		cache wwn-0x5000c500302f88cb wwn-0x5000c500302dc95b wwn-0x5000c500302dc907 wwn-0x5000c500302d439b \
		log mirror  wwn-0x5000c500a187d0d7 wwn-0x5000c500a187d2b7
	zfs set sync=disabled $POOL

}

do_fio_test() {
for config in 'draid40' 'raidz2_4stripe'
do
	zpool destroy $POOL
	$config
	for JOBS in 1 4 8 16 24 32 64; do
	for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
                        for BLK in 4k 8k 16k 32k 64k 128k 512k 1M 2M; do
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
                                    --iodepth=128 \
                                    --ioengine=libaio \
                                    --size=64G \
                                    --output-format=json | tee "$PWD/log/${config}-$PAT-$BLK-$JOBS.fio.json"
                                echo "Completed"
                        done
                done
        done
done
}
do_fio_test
