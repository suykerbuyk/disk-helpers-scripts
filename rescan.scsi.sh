#!/bin/sh
for X in $(ls /sys/class/scsi_host/) ; do echo "- - -" > /sys/class/scsi_host/$X/scan; done

# for smartpqi: https://www.kernel.org/doc/html/v5.17-rc1/scsi/smartpqi.html
for X in $(find /sys/class/scsi_host/host*/ -name rescan) ; do echo 1 >${X}; done

