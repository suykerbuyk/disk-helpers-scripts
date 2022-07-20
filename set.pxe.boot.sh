#!/bin/sh

# dmidecode -s system-product-name
# AP-RH-1 = Rockingham
# S2600WF0 = Newer Intel
# S2600GZ  = Older Intel

PN="$(dmidecode -s system-product-name)"
echo "System Product Name: $PN"


if grep -q "AP-RH-1" <<< ${PN}; then
	echo "Running on a Rockingham AP platform"
	NB=$(efibootmgr | grep IPv4 | head -1 | sed 's/Boot//g' | awk '{print $1}'  | tr -d '*')
	if [ "${NB}x" != "x" ] ; then
		echo "Selecting $NB for iPXE Rockingham boot"
		efibootmgr -n ${NB}
	else
		echo "Failed to parse out the net boot interface"
		efibootmgr -v
	fi

elif grep -q "S2600WF" <<< ${PN}; then
	echo "Running on Intel S2600WF platform"
	NB=$( efibootmgr -v 2>/dev/null | grep IPv4 | grep -v HTTP | sed 's/Boot//g' | head -1 | awk '{print $1}'  | tr -d '*')
	if [ "${NB}x" != "x" ] ; then
		echo "Selecting $NB for iPXE $PN boot"
		efibootmgr -n ${NB}
	else
		echo "Failed to parse out the net boot interface"
		efibootmgr -v
	fi
elif grep -q "S2600GZ" <<< ${PN}; then
	echo "Running on Intel S2600GZ platform."
	NB=$(efibootmgr -v 2>/dev/null | grep IPv4 | sed 's/Boot//g' | head -1 | awk '{print $1}'  | tr -d '*')
	if [ "${NB}x" != "x" ] ; then
		echo "Selecting $NB for iPXE $PN boot"
		efibootmgr -n ${NB}
	else
		echo "Failed to parse out the net boot interface"
		efibootmgr -v
	fi
elif grep -q "MZ72-HB" <<< ${PN}; then
	echo "Running on GigaByte Miner platform"
	NB=$(efibootmgr -v 2>/dev/null | grep IPv4 | sed 's/Boot//g' | head -1 | awk '{print $1}'  | tr -d '*')
	if [ "${NB}x" != "x" ] ; then
		echo "Selecting $NB for iPXE $PN boot"
		efibootmgr -n ${NB}
	else
		echo "Failed to parse out the net boot interface"
		efibootmgr -v
	fi
fi
