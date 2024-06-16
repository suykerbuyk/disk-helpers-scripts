zfs create -o canmount=on -o mountpoint=/storage-a ZPOOL_ict-p20-r2-c1-u21-zfs-a/storage-a
zfs create -o canmount=on -o recordsize=1M         ZPOOL_ict-p20-r2-c1-u21-zfs-a/storage-a/sealed
zfs create -o canmount=on -o recordsize=1M         ZPOOL_ict-p20-r2-c1-u21-zfs-a/storage-a/unsealed
zfs create -o canmount=on -o recordsize=256k       ZPOOL_ict-p20-r2-c1-u21-zfs-a/storage-a/cache
zfs create -o canmount=on -o recordsize=256k       ZPOOL_ict-p20-r2-c1-u21-zfs-a/storage-a/update
zfs create -o canmount=on -o recordsize=256k       ZPOOL_ict-p20-r2-c1-u21-zfs-a/storage-a/update-cache
