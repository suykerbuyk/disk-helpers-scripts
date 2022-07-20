#!/bin/sh
LVM_VG_PREFIX='sgt_vg'
LVM_LV_PREFIX='sgt_lv'

# SuSE flavors
#LVM_VG_PREFIX='ceph'
#LVM_LV_PREFIX='osd'

#for x in $(./devmap.sh  | awk -F ' ' '{print $2}' | grep -v ':'); do dd if=/dev/zero of=/dev/disk/by-id/${x} bs=1M & done

msg() {
	printf "$@\n"
}
run() {
	printf " $@ \n"
	eval "$@"; ret=$?
	[[ $ret == 0 ]] && return 0
   	printf " $@ - ERROR_CODE: $ret\n"
	exit $ret
}

rm_vg_devs() {
	msg "Purging volume groups"
	for VG in $( pvs | grep "${LVM_VG_PREFIX}" | awk '{print $2}' | sort -u)
	do
		PVS=$( pvs | grep $VG | awk '{ print $1 }'| tr '\n' ' ')
		run "   vgremove -y $VG"
		run "   pvremove -y $PVS"
	done
}
rm_vg_devs
