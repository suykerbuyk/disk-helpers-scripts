#!/bin/bash
nvme list-subsys -o json | jq -r '.Subsystems[] | [.NQN, .Paths[].Name, .Paths[].Address] | join(" ") ' | grep PM9A3

#/opt/xensource/libexec/xen-cmdline --get-dom0 xen-pciback.hide
#/opt/xensource/libexec/xen-cmdline --set-dom0 "xen-pciback.hide=(0000:c2:00.0)(0000:82:00.0)(0000:83:00.0)(0000:84:00.0)"
#/opt/xensource/libexec/xen-cmdline --delete-dom0 xen-pciback.hide
#xe vm-param-set other-config:pci=0/0000:c2:00.0,0/0000:82:00.0,0/0000:83:00.0,0/000:84:00.0 uuid=12ae1d39-f193-8bf0-319a-7dd6c301db51 
# xl pci-assignable-list

/opt/xensource/libexec/xen-cmdline --set-xen "extra_guest_irqs=128"
/opt/xensource/libexec/xen-cmdline --set-dom0 "xen-pciback.hide=(0000:c2:00.0)(0000:82:00.0)(0000:83:00.0)(0000:84:00.0)(0000:05:00.0)(0000:06:00.0)(0000:07:00.0)(0000:08:00.0)(0000:0b:00.0)(0000:0c:00.0)(0000:0d:00.0)(0000:0e:00.0)"
xe vm-param-set other-config:pci=0/0000:c2:00.0,0/0000:82:00.0,0/0000:83:00.0,0/000:84:00.0,0/0000:05:00.0,0/0000:06:00.0,0/0000:07:00.0,0/0000:08:00.0,0/0000:0b:00.0,0/0000:0c:00.0,0/0000:0d:00.0,0/0000:0e:00.0 uuid=12ae1d39-f193-8bf0-319a-7dd6c301db51 
