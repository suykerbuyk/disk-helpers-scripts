#!/bin/sh

. /etc/*release
SNAME=$(dmidecode -s system-product-name)
SUUID=$(dmidecode -s system-uuid)
BMC_MAC=$(ipmitool lan print | grep "MAC Address"  | sed 's/MAC Address             : //g')
BMC_IP=$( ipmitool lan print | grep "IP Address   "| sed 's/IP Address              : //g')
CPU_ID=$(cat /proc/cpuinfo  | egrep 'model name.*: ' | head -1 | sed -e 's/.*: //g')
CPU_CNT=$(cat /proc/cpuinfo  | egrep 'model name.*: ' | wc -l)

echo -n "$HOSTNAME, $SNAME, $ID, $VERSION_ID, $CPU_ID, $CPU_CNT, $SUUID, $BMC_MAC, $BMC_IP"
for NIC in $(ip a | grep 'mq state UP group' | grep -v dock | awk '{print $2'} | tr -d ':')
do
	IP="$(ip address show $NIC | grep 'inet ' | awk '{print $2}' | sed 's/\/.*//g')"
	MAC="$(ip address show $NIC | grep ' link/ether ' | awk '{print $2}')"
	if [ "${IP}x" == "x" ] ; then
		IP="000.00.00.00"
	fi
	echo -n ", $NIC, $IP, $MAC"
done
echo
