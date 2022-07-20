#! /bin/sh

if [[ $# -eq 0 ]] ; then
    echo 'please provide a space-separated list of drives to zap'
    exit 0
fi

for drive in $@
  do

    # check that drive exists ( Warning - fair game that this could blitz OS )
    lsblk ${drive} >/dev/null 2>&1 && {

    echo "Drive : ${drive}"
    echo "======="

	# Wipe the beginning of each partition
	for partition in ${drive}[0-9]
	  do
		ls ${partition} >/dev/null 2>&1 && dd if=/dev/zero of=${partition} bs=4096 count=1 oflag=direct
		# echo -n " p "
	  done

	# Wipe the beginning of the drive: 
	dd if=/dev/zero of=${drive} bs=512 count=34 oflag=direct # && echo -n " b "

	# Wipe the end of the drive: 
	dd if=/dev/zero of=${drive} bs=512 count=33 \
	  seek=$((`blockdev --getsz ${drive}` - 33)) oflag=direct # && echo -n " e "

	# Zap the GPT/MBR drive data structures:
	$(type sgdisk >/dev/null 2>&1) && sgdisk -Z --clear -g ${drive} # && echo -n " gm "

	# Verify that the drive is empty (with no GPT structures):
	parted -s ${drive} mklabel msdos
	parted -s ${drive} print free # && echo " e"

    }

  done

