#!/bin/bash
# vim:ff=unix noati:ts=4:ss=4
#!/bin/sh

MACH2='wwn-0x6000c500a'
EVANS='wwn-0x5000c500a'
TATSU='wwn-0x5000c5009'
X2SAS='wwn-0x6000c500d'

#for x in $(./devmap.sh  | awk -F ' ' '{print $2}' | grep -v ':'); do dd if=/dev/zero of=/dev/disk/by-id/${x} bs=1M & done

enclosure_sg=$(lsscsi -g \
   | grep -i enclos | grep -i SEAGATE \
   | awk '{ print $7 }' | tail -1)
map_disk_slots() { 
	for dev in $(ls /dev/disk/by-id/ | grep "$1" | grep -v part) 
	do

       d="/dev/disk/by-id/$dev"
       this_sn=$(sg_vpd --page=0x80 $d \
           | grep 'Unit serial number:' \
           | awk -F ' ' '{print $4}')
       sas_address=$(sg_vpd --page=0x83 ${d} \
           | grep -A 3 'Target port:' \
           | grep "0x" | tr -d ' ' \
           | cut -c 3-)
       device_slot=$(sg_ses -p 0xa ${enclosure_sg} \
           | grep -B 8 -i $sas_address  \
           | grep 'device slot number:'  \
           | sed 's/^.*device slot number: //g')
       device_slot=$(printf "%03d" $device_slot)
       kdev=$(readlink -f $d)
       echo "  slot=$device_slot $dev sas_addr=$sas_address s/n=$this_sn $kdev"
   done
}
for DSK_TYPE in MACH2 EVANS TATSU X2SAS
do
	DSK_PREFIX="${!DSK_TYPE}"
	echo "$DSK_TYPE ($DSK_PREFIX):"
	map_disk_slots "${DSK_PREFIX}"
done
