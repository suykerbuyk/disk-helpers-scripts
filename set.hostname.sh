#!/bin/sh
if [ -d /etc/sysconfig/network ] ; then
	for X in $(find  /etc/sysconfig/network/ -maxdepth 1 -type f ) ; do
		sed -i "s/DHCLIENT_SET_HOSTNAME=.*yes.*/DHCLIENT_SET_HOSTNAME='no'/g" ${X}
	done
fi
hostnamectl set-hostname $(hostname | sed 's/-mgmt.*//g')
hostnamectl set-hostname $(hostname | sed 's/-data.*//g')
