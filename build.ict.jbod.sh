#!/bin/bash
set -e

HNAME="$(uname -n)"
DEV_FILE="${HNAME}-devmap.txt"
ENC_FILE="${HNAME}-encmap.txt"

build_devmap() {
	./devmap.sh | sort | tee "${DEV_FILE}"
	cp "${DEV_FILE}" /etc/zfs/vdev_id.conf 
	udevadm trigger
}
build_encmap() {
cat "${DEV_FILE}" | awk '{print $2}' | awk -F '_' '{print $1}' | sort -u | tee "${ENC_FILE}"
for ENC in $(cat "${ENC_FILE}")
do
	cat "${DEV_FILE}" | grep "${ENC}" >"${HNAME}-${ENC}-devmap.txt"
done
}
build_devmap
build_encmap
