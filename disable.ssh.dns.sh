#!/bin/sh
sed -i  's/.*UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config
