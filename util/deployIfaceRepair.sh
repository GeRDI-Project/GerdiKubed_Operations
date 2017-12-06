#!/bin/bash
# usage example ./deployIfaceRepair.sh 10.155.209.23 141.40.254.131
ip=$1
ipext=$2
[ -z $3 ] || gw=$3
[ -z $3 ] && gw=141.40.255.254
[ -z $4 ] || nw=$4
[ -z $4 ] && nw=141.40.254.0/23
[ -z $5 ] || if=$5
[ -z $5 ] && if="ens3"

echo "Connecting to $ip to repair $if($ipext) with gw $gw and nw $nw"

echo "Install script"
scp repairIface.sh root@$ip:repairIface.sh
scp repairIface.service root@$ip:/etc/systemd/system/repairIface.service
ssh root@$ip "sed -i 's#__IP__#$ipext#g;
                      s#__GW__#$gw#g;
                      s#__NW__#$nw#g;
                      s#__IF__#$if#g' /root/repairIface.sh"
ssh root@$ip 'apt install iproute2 -y'
echo "Enabling service"
ssh root@$ip 'systemctl enable repairIface.service'
ssh root@$ip 'systemctl daemon-reload'
echo "Reboot"
ssh root@$ip reboot
