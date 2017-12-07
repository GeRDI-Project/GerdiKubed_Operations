#!/bin/bash
curNum=0
for iface in `ip a | grep -v ovs-system | grep 'state UP' | awk -F ':' '{ print $2 }'`
do
  let "curNum++"
  if [ "$curNum" -eq "$1" ]
  then
    ip=$(ip a | grep inet | grep $iface | awk '{ print $2 }' | awk -F '/' '{ print $1 }')
    gw=$(ip route | grep default | grep $iface | awk '{ print $3 }')
    nw=$(ipcalc $(ip a | grep inet | grep $iface | awk '{ print $2 }' | awk -F '/' '{ print $1 }' | tr '\n' ' ') | grep 'Network:' | awk '{ print $2 }')
    min=$(ipcalc $(ip a | grep inet | grep $iface | awk '{ print $2 }' | awk -F '/' '{ print $1 }' | tr '\n' ' ') | grep 'HostMin:' | awk '{ print $2 }')
    max=$(ipcalc $(ip a | grep inet | grep $iface | awk '{ print $2 }' | awk -F '/' '{ print $1 }' | tr '\n' ' ') | grep 'HostMax:' | awk '{ print $2 }')
    output="$iface $ip $gw $nw $min $max"
    echo $output | tr '\n' ' '
    echo
    exit 0
  fi
done
exit 100
