#!/bin/sh

# lsblk -JO | jq -r '."blockdevices"[] | select( .group == "disk" and .vendor == "SEAGATE ")| ."model" + " " + ."path" + " " + ."vendor" + " " + .serial + " " +  ."size" + " "+ ."wwn" ' | grep ST1600
#lsblk -JO | jq -r '."blockdevices"[] | select( .group == "disk" and .vendor == "SEAGATE ")| ."model" + " " + ."path" + " " + ."vendor" + " " + .serial + " " +  ."size" + " "+ ."wwn" '|sort

DEVS=""
DEVCNT=0
CDEVS=""
CDEVCNT=0
POOL=ztank

for X in $(lsblk -JO | jq -r '."blockdevices"[] | select( .group == "disk" and .vendor == "SEAGATE " and .size =="14.6T")|"wwn-"+ ."wwn"')
do
	DEVS="${DEVS} ${X}"
	DEVCNT=$((DEVCNT+1))
done
for X in $(lsblk -JO | jq -r '."blockdevices"[] | select( .group == "disk" and .vendor == "SEAGATE " and .size =="3.5T")|"wwn-"+ ."wwn"')
do
	CDEVS="${CDEVS} ${X}"
	CDEVCNT=$((CDEVCNT+1))
done
echo "DEVCNT=$DEVCNT" #echo $DEVS
echo "CDEVCNT=$CDEVCNT"
#echo $CDEVS


draid40_with_cache() {
	CDEV1="$(echo ${CDEVS} | cut -d " " -f 1-2)"
	CDEV2="$(echo ${CDEVS} | cut -d " " -f 3-4)"
	zpool create -f $POOL draid2:10d:${DEVCNT}c:4s ${DEVS} \
		cache $CDEV1 \
		log mirror  $CDEV2
	zfs set sync=disabled $POOL

}

raidz2_4stripe_with_cache() {
	VDEV1="$(echo ${DEVS} | cut -d " " -f 1-10)"
	VDEV2="$(echo ${DEVS} | cut -d " " -f 11-20)"
	VDEV3="$(echo ${DEVS} | cut -d " " -f 21-30)"
	VDEV4="$(echo ${DEVS} | cut -d " " -f 31-40)"
	CDEV1="$(echo ${CDEVS} | cut -d " " -f 1-2)"
	CDEV2="$(echo ${CDEVS} | cut -d " " -f 3-4)"
	zpool create -f $POOL \
		raidz2 $VDEV1 \
		raidz2 $VDEV2 \
		raidz2 $VDEV3 \
		raidz2 $VDEV4 \
		cache $CDEV1 \
		log mirror  $CDEV2
	zfs set sync=disabled $POOL
}
raidz2_4stripe_no_cache() {
	VDEV1="$(echo ${DEVS} | cut -d " " -f 1-10)"
	VDEV2="$(echo ${DEVS} | cut -d " " -f 11-20)"
	VDEV3="$(echo ${DEVS} | cut -d " " -f 21-30)"
	VDEV4="$(echo ${DEVS} | cut -d " " -f 31-40)"
	CDEV1="$(echo ${CDEVS} | cut -d " " -f 1-2)"
	CDEV2="$(echo ${CDEVS} | cut -d " " -f 3-4)"
	zpool create -f $POOL \
		raidz2 $VDEV1 \
		raidz2 $VDEV2 \
		raidz2 $VDEV3 \
		raidz2 $VDEV4 
	zfs set sync=disabled $POOL
}
raidz2_4stripe_only_zil() {
	VDEV1="$(echo ${DEVS} | cut -d " " -f 1-10)"
	VDEV2="$(echo ${DEVS} | cut -d " " -f 11-20)"
	VDEV3="$(echo ${DEVS} | cut -d " " -f 21-30)"
	VDEV4="$(echo ${DEVS} | cut -d " " -f 31-40)"
	CDEV1="$(echo ${CDEVS} | cut -d " " -f 1-2)"
	CDEV2="$(echo ${CDEVS} | cut -d " " -f 3-4)"
	zpool create -f $POOL \
		raidz2 $VDEV1 \
		raidz2 $VDEV2 \
		raidz2 $VDEV3 \
		raidz2 $VDEV4 \
		log mirror  $CDEV2
	zfs set sync=disabled $POOL
}
draid4x10_with_cache() {
	VDEV1="$(echo ${DEVS} | cut -d " " -f 1-10)"
	VDEV2="$(echo ${DEVS} | cut -d " " -f 11-20)"
	VDEV3="$(echo ${DEVS} | cut -d " " -f 21-30)"
	VDEV4="$(echo ${DEVS} | cut -d " " -f 31-40)"
	CDEV1="$(echo ${CDEVS} | cut -d " " -f 1-2)"
	CDEV2="$(echo ${CDEVS} | cut -d " " -f 3-4)"
	DRAID="draid2:8d:10c:0s"
	zpool create -f $POOL \
		$DRAID $VDEV1 \
		$DRAID $VDEV2 \
		$DRAID $VDEV3 \
		$DRAID $VDEV4 \
		cache $CDEV1 \
		log mirror  $CDEV2
	zfs set sync=disabled $POOL

}
draid4x11_with_cache() {
	VDEV1="$(echo ${DEVS} | cut -d " " -f 1-11)"
	VDEV2="$(echo ${DEVS} | cut -d " " -f 12-22)"
	VDEV3="$(echo ${DEVS} | cut -d " " -f 23-33)"
	VDEV4="$(echo ${DEVS} | cut -d " " -f 34-44)"
	CDEV1="$(echo ${CDEVS} | cut -d " " -f 1-2)"
	CDEV2="$(echo ${CDEVS} | cut -d " " -f 3-4)"
	DRAID="draid2:8d:11c:1s"
	zpool create -f $POOL \
		$DRAID $VDEV1 \
		$DRAID $VDEV2 \
		$DRAID $VDEV3 \
		$DRAID $VDEV4 \
		cache $CDEV1 \
		log mirror  $CDEV2
	zfs set sync=disabled $POOL

}

draid4x11_no_cache() {
	VDEV1="$(echo ${DEVS} | cut -d " " -f 1-11)"
	VDEV2="$(echo ${DEVS} | cut -d " " -f 12-22)"
	VDEV3="$(echo ${DEVS} | cut -d " " -f 23-33)"
	VDEV4="$(echo ${DEVS} | cut -d " " -f 34-44)"
	CDEV1="$(echo ${CDEVS} | cut -d " " -f 1-2)"
	CDEV2="$(echo ${CDEVS} | cut -d " " -f 3-4)"
	DRAID="draid2:8d:11c:1s"
	zpool create -f $POOL \
		$DRAID $VDEV1 \
		$DRAID $VDEV2 \
		$DRAID $VDEV3 \
		$DRAID $VDEV4 
	zfs set sync=disabled $POOL

}



do_fio_test() {
logpath="$PWD/iodepth_test"
if [ ! -d "${logpath}" ] ; then 
	mkdir "${logpath}"
fi
for config in raidz2_4stripe_no_cache raidz2_4stripe_with_cache
do
	zpool destroy $POOL
	$config
	for IOENGINE in 'io_uring' 'libaio'
	do
		for IODEPTH in 1 8 16 64 128; do
			for JOBS in 1 4 8 16 24 32 64; do
				for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
					for BLK in 4k 8k 16k 32k 64k 128k 512k 1M 2M; do
						TEST="${config}-${IOENGINE}-${IODEPTH}-${PAT}-${BLK}-${JOBS}.fio.json"
						echo "Running $TEST"
						fio --directory=/$POOL/ \
						    --name="${config}" \
						    --rw=$PAT \
						    --group_reporting=1 \
						    --bs=$BLK \
						    --direct=1 \
						    --numjobs=$JOBS \
						    --time_based=1 \
						    --runtime=180 \
						    --iodepth=$IODEPTH \
						    --ioengine=$IOENGINE \
						    --size=128G \
						    --output-format=json | tee "${logpath}/${TEST}"
						echo "Completed"
					done
				done
			done
		done
	done
done
}
#do_fio_test
#draid4x10
#do_fio_test
#draid4x11
raidz2_4stripe_with_cache
