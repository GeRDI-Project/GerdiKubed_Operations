# Installation on LRZ VMWare Hosts

## Second Network Interface (eth1) for Debian VMWare Hosts (LRZ)
The debian host for the lb is configured with two network interfaces eth0 --> MWN and 
eth1 --> Internet which are both part of different subnets. For the lb-0.a.gerdi.org 
the second interface needs to be configured with a different routing table (rt2). First 
add the new routing table to /etc/iproute2/rt_tables.

```bash
echo "1 rt2" >> /etc/iproute2/rt_tables
```

Next the new interface need to be added to /etc/network/interfaces. As Debian the gateway
parameter just sets the default gateway, and two of them are not possible,  you have to 
configure the interface routing using ip route.

```
# The secondary network interface
auto eth1
iface eth1 inet static
	address 129.187.252.21
	netmask 23
	post-up ip route add 129.187.252.0/23 dev eth1 src 129.187.252.21 table rt2
   	post-up ip route add default via 129.187.253.254 dev eth1 table rt2
    	post-up ip rule add from 129.187.252.21/32 table rt2
    	post-up ip rule add to 129.187.252.21/32 table rt2
```
Restart the network service.

```bash
`systemctl restart networking.service
```
