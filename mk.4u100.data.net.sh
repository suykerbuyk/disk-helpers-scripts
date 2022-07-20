#!/bin/sh
set -e
nmcli conn del data-bond  || true
nmcli conn del enp175s0f0 || true
nmcli conn del enp175s0f1 || true
nmcli connection add type bond con-name data-bond ifname data-bond bond.options "mode=balance-alb,miimon=1000" mtu 9000
nmcli conn add type bond-slave ifname enp175s0f0 con-name enp175s0f0 master data-bond mtu 9000
nmcli conn add type bond-slave ifname enp175s0f1 con-name enp175s0f1 master data-bond mtu 9000
