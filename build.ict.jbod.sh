#!/bin/bash

HNAME="$(uname -n)"
OFILE="${HNAME}-devmap.txt"

sudo ./devmap.sh | sort | tee "${OFILE}"
sudo "${OFILE}" /etc/zfs/vdev_id.conf 
sudo udevadm trigger

cat "${OFILE}" | awk '{print $2}' | awk -F '_' '{print $1}' | sort -u | tee "${HNAME}-encmap.txt"
