# Deployment on an OpenStack Private/Public Cloud

Like other cloud providers, OpenStack has some specialities which need to be considered before deploying the playbooks
to virtual maschines. First of all you habe to adjust your security group settings in order to limit access during the
installation process and to allow sufficient access to you API and virtual hosts. If you use a default iamge provided
by either OpenStack iteself or by some distro repository, you habe to make some changes in order to get root access.

## Setup of Security Groups

In order to achieve maximum security, you should adjust your security rules accordingly. As the cluster itself should
be fully separated from the outside world, we propose the use of three security groups:

1. k8s-nodes-group
2. k8s-master-group
3. k8s-lb-group

Although we limit access to the nodes by the UFW firerwall, OpenStack security groups provide a second security layer
and ingress and egress rules have to be adjusted in order to get access to the nodes. Commonly, OpenStack security
groups only allow outgoing (egress) traffic but block any incoming (ingress) traffic. Hence it is important to open
certain ports for ingress traffic. The according ports, protocols and Targets are listed in the following tables.

### k8s-nodes-group

This groups contains all nodes, masters and loadbalancer nodes. As they have to communicate with each other, TCP and
ICMP traffic between nodes in the security group is allowed as well as UDP. UDP is required for the geneve tunnel.

| Direction | Protocol  | Port Range    | Remote IP/Security Group  |
| --------- | --------- | ------------- | ------------------------- |
| Egress    | Any       | Any           | 0.0.0.0/0                 |
| Ingress   | ICMP      | Any           | k8s-nodes-group           |
| Ingress   | UDP       | Any           | k8s-nodes-group           |
| Ingress   | TCP       | Any           | k8s-nodes-group           |
| Ingress   | TCP       | 22            | <private-network>         |

### k8s-master-group

This group only contains hosts, which act as k8s-master server. As the master hosts the API server, access to port 443
from a private network is necessary. We do not recommend acces from any IP, although it is possible. In addition, the
API server needs to be accessible from the nodes in the cluster. Therefore, port 443 is opened for the nodes security
group. As the nodes don't need to be accessible at port 443, we make this change at the master level.

| Direction | Protocol  | Port Range    | Remote IP/Security Group  |
| --------- | --------- | ------------- | ------------------------- |
| Ingress   | TCP       | 443           | k8s-nodes-group           |
| Ingress   | TCP       | 443           | <private-network>         |

### k8s-lb-group

As the lb acts as gateway, we suggest to open the HTTP and HTTPS ports to the outside world. However, in some cases it
may be necessary to open further ports, depending on the configuration.

| Direction | Protocol  | Port Range    | Remote IP/Security Group  |
| --------- | --------- | ------------- | ------------------------- |
| Ingress   | TCP       | 80            | 0.0.0.0/0                 |
| Ingress   | TCP       | 443           | 0.0.0.0/0                 |
