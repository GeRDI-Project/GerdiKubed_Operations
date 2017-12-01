#!/bin/bash
curNum=0
for iface in `ip a | grep -v ovs-system | grep 'state UP' | awk -F ':' '{ print $2 }'`
do
  let "curNum++"
  if [ $curNum == $1 ]
  then
    echo -n "$iface "
    ip a | grep inet | grep $iface | awk '{ print $2 }' | awk -F '/' '{ print $1 }' | tr '\n' ' '
    ip route | grep default | grep $iface | awk '{ print $3 }'
  fi
done
