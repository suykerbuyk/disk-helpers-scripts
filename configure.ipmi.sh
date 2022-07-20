#!/bin/bash

MY_NAME=$(uname -n)
NET_INFO_FILE=$MY_NAME.net.info.txt

TARGET=$1
if [ "$1x" == "x" ] ; then
	echo "Setting BMC NICs to dhcp"
	for x in $(seq 1 3); do
		# echo "ipmitool lan set $x ipsrc dhcp"
		ipmitool lan set $x ipsrc dhcp >/dev/null
	done
	echo "Enabling access channels"
	for x in $(seq 1 3); do
		for y in $(seq 1 3); do
			# echo ipmitool channel setaccess $x $y link=on ipmi=on callin=on privilege=4
			ipmitool channel setaccess $x $y link=on ipmi=on callin=on privilege=4 >/dev/null
		done
	done
	truncate -s 0 $NET_INFO_FILE

	echo "Configuring BMC users"
	ipmitool user set name 2 root >/dev/null
	ipmitool user set name 3 admin >/dev/null
	ipmitool user set password 2 clandestine  >/dev/null
	ipmitool user set password 3 clandestine >/dev/null

	echo "Gathering BMC NIC info"
	for x in $(seq 1 3); do
		NIC_NAME=$(echo "$MY_NAME-ipmi-$x                    " | head -c 23)
		BMC_MAC=$(ipmitool lan print $x |  grep 'MAC Address  ' | sed 's/ //g' | sed 's/MACAddress://g')
		IP_ADDR=$(ipmitool lan print $x | grep 'IP Address      ' | sed 's/ //g' | sed 's/IPAddress://g')
		echo " $NIC_NAME $BMC_MAC   $IP_ADDR" | tee -a $NET_INFO_FILE
	done

	echo "Gathering HOST NIC info"
	for x in $(ip link| grep 'BROADCAST' | awk -F ':' '{print $2}'); do
                NIC_NAME=$(echo -n "$x                   " | head -c 15)
		NIC_MAC=$(ip link show $x)
		NIC_MAC=$(echo $NIC_MAC  | sed  's/.*ether //' | sed 's/brd.*//')
                NIC_MAC=$(echo "$NIC_MAC                     " | head -c 19)
		NIC_IP=$(ip addr show $x | grep 'inet ' | awk -F ' ' '{print $2}' | sed 's/\/.*//')
                if [ -z $NIC_IP ]; then
			NIC_IP='xxxxxxxxxxxx'
		fi
		NIC_IP=$(echo -n "$NIC_IP            " | head -c 15)
		MAX_SPD=$(ethtool $x | grep base | cut -b 26- | cut -d '/' -f1 | sort -u | head -1)
		printf " $MY_NAME $NIC_NAME $NIC_MAC $NIC_IP $MAX_SPD \n" | tee -a $NET_INFO_FILE
	done
else
	NET_INFO_FILE=$TARGET.net.info.txt
	scp $0 root@$TARGET:
	ssh root@$TARGET ./`basename $0`
	scp root@$TARGET:$NET_INFO_FILE ./net.info/
fi
