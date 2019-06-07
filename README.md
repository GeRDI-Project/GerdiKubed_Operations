
# GerdiKubed

This repo has all necessary roles to setup a kubernetes cluster (req. see below).
There are multiple playbooks in the root of the git repository:

*Note: In order of execution!*

* k8s-mgmt.yml
* (k8s-nfs.yml; *Optional*)
* k8s-master.yml
* k8s-nodes.yml
* k8s-lb.yml
* k8s-stack.yml
* (k8s-gerdi.yml; *Optional*)

# Usage

```bash
# Initial setup
# Create new inventory from template:
cp -r inventory/dev.gerdi.research.lrz.de inventory/<deployment-context>

# Edit variable-template and inventory file-template:
# (Consult role documentation for answers)
vi inventory/<deployment-context>/hosts.ini
vi inventory/<deployment-context>/group_vars/all.yml

# -------------------------------------------------------------------------------------------#

# Setup certificates:
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-mgmt.yml
# This has to be done only once per cluster!
# Delete or move CONTROL_BASE_DIR to reset and recreate all certificates.

# (Setup NFS server; Optional)
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-nfs.yml

# Setup master(s)
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-master.yml

# Setup nodes
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-node.yml

# Setup loadbalancer (requires valid certificates for k8s domain namespace)
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-lb.yml

# Deploy the k8s stack for monitoring and management
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-stack.yml

# (Execute the gerdi specific tasks; Optional)
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-gerdi.yml
```

# Requirements

* Debian 9.1 or higher on the remote machines (you can use the [recipe](util/CreateVMImage.md) to create a VM image against which these scripts have been tested).
* Running sshd on the remote machines and on the control machine (preferrably localhost) and the package python-dnspython
* Pub key in .ssh/authorized\_keys in roots's home on the remote machines
* Python > 2.6
* Ansible >= 2.8.0.0 (on the control machine, only linux distros are supported!)
* All nodes must have valid DNS-Records (configured in production). IP-Addresses are no longer supported. If this condition is not fulfilled the k8s-mgmt.yml-playbook will fail.
* Nodes must follow the following network interface setup:
  * One *private* network interface for k8s-nodes and k8s-master.
  * One *private* and one *public* interface for load balancer nodes.
* The playbooks assume the following order:
  * First interface (private): SSHD listening & OVN overlay network interface
  * Second interface (public): Internet endpoint (load balancer only)

**Interface setup:**

```Bash
      +--------------+
      |  k8s|master  |
      +--------------+
      |              |
SSH+--+    iface1    +----+
      |              |    |
      |              |    |
      +--------------+    |
                          |
      +--------------+    |
      |  k8s|node(s) |    |
      +--------------+    |
      |              |    |
SSH+--+    iface1    +---OVN (geneve)
      |              |    |
      |              |    |
      +--------------+    |
                          |
      +--------------+    |
      |    k8s|lb    |    |
      +--------------+    |
      |              |    |
SSH+--+    iface1    +----+
      |              |               +------------+
      |    iface2    +---------------+  Internet  |
      |              |               +------------+
      +--------------+
```

Created using: http://asciiflow.com/

# Documentation

## Role Overview

*Note: For readability purposes, not in order of execution!*

|&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Playbook<br>Role <br>  |  k8s-master |  k8s-node  |  k8s-lb  |  k8s-mgmt |  k8s-nfs  |  k8s-stack  |  k8s-gerdi  |
|---|---|---|---|---|---|---|---|
| [vmware-node](#vmware-node) OR <br> [nebula-node](#nebula-node) OR <br> [openstack-node](#openstack-node) |<div align="center">x</div>|      <div align="center">x</div>      |      |      |      |      |      |
| [network-interfaces](#network-interfaces)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [common](#common)|      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [ufw](#ufw)|      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [docker](#docker)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [k8s-binaries](#k8s-binaries)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [kubelet](#kubelet)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [kube-proxy](#kube-proxy)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [network-ovn](#network-ovn)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [k8s-cordon](#k8s-cordon)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [apiserver](#apiserver)      |      <div align="center">x</div>      |      |      |      |      |      |      |
| [scheduler](#scheduler)      |      <div align="center">x</div>      |      |      |      |      |      |      |
| [controller-manager](#controller-manager)  |      <div align="center">x</div>      |      |      |      |      |      |      |
| [etcd](#etcd)      |      <div align="center">x</div>      |      |      |      |      |      |      |
| [k8s-addons](#k8s-addons)      |      <div align="center">x</div>      |      |      |      |      |      |      |
| [cni](#cni)      |      <div align="center">x</div>      |      |      |      |      |      |      |
| [cluster-dns](#cluster-dns)      |      |      |      <div align="center">x</div>      |      |      |      |      |
| [apache-proxy](#apache-proxy)      |      |      |      <div align="center">x</div>      |      |      |      |      |
| [cert-infrastructure](#cert-infrastructure)|      |      |      |      <div align="center">x</div>      |      |      |      |
| [nfs-server](#nfs-server)|      |      |      |      |      <div align="center">x</div>      |      |      |
| [prometheus](#prometheus)|      |      |      |      |      |      <div align="center">x</div>      |      |
| [secrets](#secrets)|      |      |      |      |      |      |      <div align="center">x</div>      |
| [helm](#helm)|      |      |      |      |      |      |      <div align="center">x</div>      |
| [persistent-volumes](#persistent-volumes)|      |      |      |      |      |      |      <div align="center">x</div>      |
| [jhub](#jhub)|      |      |      |      |      |      |      <div align="center">x</div>      |
| [keycloak](#keycloak)|      |      |      |      |      |      |      <div align="center">x</div>      |

## Role Documentation

<a name="apache-proxy"></a>

### apache-proxy

Handles the setup of the SSL termination infrastructure involving an apache proxy webserver.

<a name="apiserver"></a>

### apiserver

The apiserver is the management interface of the k8s cluster. It runs on the k8s-master node as a systemd-service.

<a name="cert-infrastructure"></a>

### cert-infrastructure

This role creates a ca ready infrastructure on a trusted host the localhost should be the default.
To get it working you'll have to set the following variables in group\_vars/all:

* CONTROL\_MACHINE: Trusted machine on which certificates are issued and ca's private key resides (set "127.0.0.1" for localhost)
* CONTROL\_BASE\_DIR: Directory in which certficate infrastructure is persisted.

These subdirs shouldn't be altered in group\_vars/all template (they are here for documentation purpose.

* CONTROL\_CERT\_DIR: All certificates reside here (including certification authority certificate) (Default: CONTROL\_BASE\_DIR/certs).
* CONTROL\_KEY\_DIR: All keys reside here (including private key of certification authority)( Default: CONTROL\_BASE\_DIR/keys).
* CONTROL\_CONFIG\_DIR: Openssl configs reside here (Default:  CONTROL\_BASE\_DIR/configs).
* CONTROL\_CSR\_DIR: Certificate Signing requests reside here (Default: CONTROL\_BASE\_DIR/csrs).
* CONTROL\_CA\_DIR:  Certification Authority Management files reside here (e.g. serial numbers, issued certificates, etc.) (Default: CONTROL\_BASE\_DIR/ca)

It also creates a number of certificates (both server and client) to handle authorization inside the k8s cluster (e.g. etcd <=> apiserver).

<a name="common"></a>

### common

This role sets up all machines (install packages & certificates, creates directories etc.).

<a name="controller-manager"></a>

### controller-manager

The controller-manager runs on all master instances as a systemd-service and distributes the deployments and pods to the kubelets running on the node instances.

<a name="cluster-dns"></a>

### cluster-dns

Sets up dnsmasq and forces the load balancer to use kube-dns to resolve cluster internal domains.

<a name="cni"></a>

### cni

This role handles the setup of the network cni plugin used by kubernetes.

<a name="docker"></a>

### docker

Docker is the container engine running on both the nodes and the master.

<a name="etcd"></a>

### etcd

Etcd is a distributed key-value store to persist the k8s configuration serviced by the apiserver. It is also used to synchronize several masters (and therefore several apiservers).

<a name="k8s-addons"></a>

### k8s-addons

This role sets up the kubernetes addon manager and handles the creation of the kube-dns service.

<a name="k8s-binaries"></a>

### k8s-binaries

This role fetches the kubernetes binaries in a version defined by K8S\_VERSION.
It also creates a kubeconfig that is used system wide to configure the k8s components with the whereabouts of and the credentials to the other components

<a name="k8s-cordon"></a>

### k8s-cordon

This role makes sure that the kubernetes master and loadbalancer are excluded from having pods scheduled upon them.

<a name="kubelet"></a>

### kubelet

The kubelet component is the interface to the docker daemon which makes sure the Deployments and Pods are translated into running docker containers. Kubelet runs as a systemd-service on all node and master instances.

<a name="kube-proxy"></a>

### kube-proxy

The kube-proxy takes care of proxying requests inside the k8s cluster. It runs as a systemd-service on all nodes.

<a name="network-interfaces"></a>

### network-interfaces

Sets up systemd-networkd & systemd-resolved by *'hotswapping'* the default networking.service (/etc/interfaces). Configures nameservers and network interfaces' properties to correctly fall in line with expectations of subsequent roles.

<a name="nfs-server"></a>

### nfs-server

Responsible for setting up a NFS server alongside the k8s cluster and adding all nodes from the cluster to its' exports file. This is optional, you can also choose to pick an already existing external NFS server.

<a name="network-ovn"></a>

### network-ovn

OVN/OVS is one of the possible k8s network driver (see [k8s network model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model)). This role sets up a geneve interface to tunnel and encrypt pod to pod traffic.

<a name="prometheus"></a>

### prometheus

Installs the prometheus monitoring system for central cluster and service monitoring. Prometheus [prometheus.io](https://prometheus.io/) is the default monitoring system for kubernetes and is maintained
by the Cloud Native Foundation. It provides time series related monitoring and alerting. The role creates a dedicated kube-monitor namespace and deploys the prometheus master server into it.

<a name="scheduler"></a>

### scheduler

The scheduler runs scheduled pods. It operates on the k8s-master as a systemd-service.

<a name="ufw"></a>

### ufw

This role sets up the uncomplicated firewall (ufw). Depending on which node it's executed on, it will vary the port openings, for example the load balancer will receive additional openings at TCP/80 and TCP/443. 

## Node Specific Roles

<a name="vmware-node"></a>

### vmware-node

This role is tailored to VMware machines running on LRZ infrastructure. Depending on the node, different steps have to be performed to bring each node into a state that allows the subsequent roles to be executed properly.

<a name="nebula-node"></a>

### nebula-node

*Note: Obsolete, will be removed in the future (Fall 2019)*
This role is tailored to OpenNebula machines using the image generated by this [script](util/CreateVMImage.md) running on LRZ infrastructure. Depending on the node, different steps have to be performed to bring each node into a state that allows the subsequent roles to be executed properly.

<a name="openstack-node"></a>

### openstack-node

This role is tailored to Openstack machines running on LRZ infrastructure. It features support for floating IPs and security groups. Depending on the node, different steps have to be performed to bring each node into a state that allows the subsequent roles to be executed properly.

# CI

The repository is checked by a CI-Task in Bamboo (push to bitbucket). You can't merge a PR that wasn't build successfully!
