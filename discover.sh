#!/bin/bash


Get_IPs (){
	if [ $(which sdparm) ] ; then
		for SG_DEV in $(ls /dev/sg*)
		do
			sg_inq  ${SG_DEV}  | grep SEAGATE -a2 | grep -a1 6575 | grep S100 >/dev/null &&
				sg_inq ${SG_DEV} --vpd -p 0x85 | grep 'http' | tr -d ' '
		done | sort -u | sed 's|http://||g' | tr '\n' ' '
	elif [ $(which sg_inq) ]; then
		for SG_DEV in $(sdparm /dev/sg* --inquiry -p 0 | grep -e 'SEAGATE.*6575' | sed 's/:.*$//g' | tr -d ' ')
		do
			sudo sdparm ${SG_DEV}  --inquiry -p 0x85 | grep http | sed 's/http:\/\///g' | tr -d ' '
		done | sort -u
	else
		echo "Please install either sg3-utils or sdparm to continue"
		exit 1
	fi
}
Get_IPs
