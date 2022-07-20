#!/bin/bash
set -e
POOL_NAME=JBOD
LUN_PATTERN="/dev/disk/by-id/dm-uuid-mpath-35000c500d7*"
LOGDIR=test

if [ ! -d ${LOGDIR} ]; then
        mkdir ${LOGDIR}
fi


#echo 1000 >/sys/module/zfs/parameters/zfs_multihost_fail_intervals
echo $((16 * 1024 * 1024 *1024)) >/sys/module/zfs/parameters/zfs_arc_max

wipe_zfs_pools() {
        for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}')
        do
                echo "zpool destroy $POOL"
                zpool destroy $POOL &
        done
        wait
        # clear out the primary ZFS partion
        for X in $(ls ${LUN_PATTERN} | grep part1)
        do
                echo "zpool labelclear -f ${X} && wipefs -a ${X}"
                zpool labelclear -f ${X} && wipefs -a ${X} &
        done
        wait

        # clear out the residual end of disk partition
        for X in $(ls ${LUN_PATTERN} | grep part9)
        do
                echo "wipefs -a ${X}"
                wipefs -a ${X} &
        done
        wait

        # Finally, wipe out the GPT partions.
        for X in $(ls ${LUN_PATTERN} | grep -v part)
        do
                echo "sgdisk -Z ${X}"
                sgdisk -Z ${X} &
        done
        wait
        sleep 1
}

rescan_scsi_bus() {
        # Rescan the SCSI bus
        for X in $(ls /sys/class/scsi_host/)
        do
                echo "- - -" > /sys/class/scsi_host/$X/scan &
        done
        wait
}



create_draid_zpool() {
        wipe_zfs_pool
        #zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 draid2:4d:6c:0s  ${LUN_PATTERN}
        zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 draid2:16d:2s:106c  ${LUN_PATTERN}
}
create_raidz2_zpool() {
        wipe_zfs_pool
        zpool create ${POOL_NAME}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 raidz2  ${LUN_PATTERN}
}
create_individual_pools() {
        wipe_zfs_pools
        IDX=0
        for X in $(ls ${LUN_PATTERN} | grep -v part)
        do
                zpool create ${POOL_NAME}_${IDX}  -O recordsize=512K -O atime=off -O dnodesize=auto -o ashift=12 $X
                IDX=$((IDX+1))
        done
        sleep 1
}
create_jbod_zfs_draid_pool() {
        POOL_NAME="JBOD"
        TOPOLOGY='draid'
        VDEV_DISKS=13
        VDEV_DATA=10
        VDEV_PARITY=2
        VDEV_SPARES=1


        for D in $(ls ${LUN_PATTERN} ) ; do
                DEVS="${DEVS} ${D}"
                DCNT=$((DCNT+1))
        done
        VDEVCNT=$((DCNT/VDEV_DISKS))

        VDEVTYPE="${TOPOLOGY}${VDEV_PARITY}:${VDEV_DATA}d:${VDEV_SPARES}s:${VDEV_DISKS}c"
        CREATE_CMD="zpool create ${POOL_NAME} "
        for IDX in $(seq 0 $((VDEVCNT-1)))
        do
                VDEVS=$(echo $DEVS | cut -d " " -f $((1 + (IDX * VDEV_DISKS)))-$(((IDX+1) * VDEV_DISKS)))
                CREATE_CMD="${CREATE_CMD} ${VDEVTYPE} ${VDEVS}"
        done
        $CREATE_CMD
}


wipe_zfs_pools
#rescan_scsi_bus
# create_individual_pools
create_jbod_zfs_draid_pool
# #clear all dmesg history
# dmesg -c
#for IOENGINE in libaio io_uring; do
for IOENGINE in libaio ; do
        for IODEPTH in 1 8 16 32; do
                for JOBS in 1 4 8 16 32; do
                        for PAT in 'write' 'read' 'randrw' 'randread' 'randwrite'; do
                        #for PAT in 'write'  'randrw' 'randwrite'; do
                                for BLK in 32k 128k 256k 512k 1024k 8192k 32768k; do
                                #for BLK in 1024k 8192k 32768k; do
                                        for POOL in $(zpool list -H | grep $POOL_NAME | awk '{print $1}')
                                        do
                                                TEST="${POOL}-${IOENGINE}-${IODEPTH}-${PAT}-${BLK}-${JOBS}.fio.json"
                                                echo "Running $TEST"
                                                zpool clear ${POOL}
                                                fio --directory=/${POOL} \
                                                    --name="${TEST}" \
                                                    --rw=$PAT \
                                                    --group_reporting=1 \
                                                    --bs=$BLK \
                                                    --direct=1 \
                                                    --numjobs=$JOBS \
                                                    --time_based=1 \
                                                    --runtime=30 \
                                                    --iodepth=$IODEPTH \
                                                    --ioengine=$IOENGINE \
                                                    --size=128G \
                                                    --output-format=json | tee "$PWD/${LOGDIR}/${TEST}" && \
                                                echo "Completed" &
                                        done
                                        wait
                                done
                        done
                done
        done
done
