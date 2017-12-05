#!/bin/bash
# usage example ./deployIfaceRepair.sh 10.155.209.23 141.40.254.131
ip=$1
ipext=$2
scp repairIface.sh root@$ip:repairIface.sh
scp repairIface.service root@$ip:/etc/systemd/system/repairIface.service
ssh root@$ip "sed -i 's/__IP__/$ipext/g' /root/repairIface.sh"
ssh root@$ip 'apt install iproute2 -y'
ssh root@$ip 'systemctl enable repairIface.service'
ssh root@$ip 'systemctl daemon-reload'
ssh root@$ip reboot
