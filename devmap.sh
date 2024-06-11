#!/bin/bash
# vim:ff=unix noati:ts=4:ss=4
#!/bin/sh

MACH2='wwn-0x6000c500a'
EVANS='wwn-0x5000c500a'
TATSU='wwn-0x5000c5009'
X2SAS='wwn-0x6000c500d'
#OTHER='wwn-0x5000c500d'
#OTHER='scsi-SSEAGATE_ST18000NM004J'
#OTHER='scsi-SWDC_WUH722020BL5204'
OTHER='scsi-35000c500d'

#for x in $(./devmap.sh  | awk -F ' ' '{print $2}' | grep -v ':'); do dd if=/dev/zero of=/dev/disk/by-id/${x} bs=1M & done

SGDEVS=""
for ENC in $(lsscsi -g | grep  'enclos' | grep 'SEAGATE\|HGST' \
   | awk '{ print $7 }' )
do SGDEVS="${SGDEVS} $ENC" ; done

if [[ "X" == "X${SGDEVS}" ]]; then
        echo "No matching enclosure devices found!"
  exit 1
fi

for DEV in $(ls /dev/disk/by-id/ | grep "${OTHER}" | grep -v part )
do
        DSK="/dev/disk/by-id/$DEV"
        this_sn=$(sg_vpd --page=0x80 $DSK \
                | grep 'Unit serial number:' \
                | awk -F ' ' '{print $4}')
        sas_address=$(sg_vpd --page=0x83 ${DSK} \
                | grep -A 3 'Target port:' \
                | grep "0x" | tr -d ' ' \
                | cut -c 3-)
        kdev=$(readlink -f $DSK)
  device_slot=""
  for ENC in ${SGDEVS}
        do
        device_slot=$(sg_ses -p 0xa ${ENC} \
                        | grep -A 8 'Element index: ' \
                        | grep -B 6 -i $sas_address \
                        | grep 'device slot number:' \
                        | sed 's/^.*device slot number: //g' )
                if [[ "X" != "X${device_slot}" ]] ; then
                        break
                fi
        done
        if [[ "X" == "X${device_slot}" ]] ; then
                echo "Error: Could not find $sas_address"
        fi
        device_slot=$(printf "%03d\n" ${device_slot})
	ENC_PADDED="$(printf "%-12s" ${ENC})"
	KDEV_PADDED=$(printf "%-10s" ${kdev})
	ENC_ID="$(sg_inq $ENC | grep 'Product identification:\|Unit serial number:' | awk -F ':' '{print $2}' | tr -d ' ' | tr '\n' ' ')"
	ENC_SERIAL=$(echo $ENC_ID | awk '{print $2}')
	#ENC_ID="$(sg_inq $ENC | grep 'Product identification:\|Unit serial number:' | awk -F ':' '{print $2}' | tr -d ' ' | tr -d '\n')"
        KDEV=$(echo "$kdev" | awk -F '/' '{print $3}')       
        EXTRA="$(ls -lah /dev/disk/by-id/ | grep -E ${KDEV}$ | grep -v part | awk '{print $9}' | sort |  tr '\n' '\t')"
	SCSI_PATH_ID=$(echo $EXTRA | awk '{print $1}')
	WWN_PATH_ID=$(echo $EXTRA | awk '{print $2}')
        #printf "${ENC_ID} sg=${ENC_PADDED}slot=${device_slot} ${dev} s/n=$this_sn sas_addr=$sas_address $KDEV_PADDED ${EXTRA}\n"
	printf "alias ${ENC_SERIAL}_${device_slot}_${this_sn}  /dev/disk/by-id/${SCSI_PATH_ID} # ${KDEV_PADDED} ${ENC_PADDED} /dev/disk/by-id/${WWN_PATH_ID} sas_addr=${sas_address}\n"
done
