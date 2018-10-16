# GerdiKubed

This repo has all necessary roles to setup a kubernetes cluster (req. see below).

There are three major playbooks in the root of the git-repo (for the others see below):
* k8s-master.yml
* k8s-nodes.yml
* k8s-mgmt.yml

# Usage

```bash

# Edit variable-template (see role documentation for questions):
cp group_vars/all.tmpl group_vars/all
vi group_vars/all

# Edit inventory file-template
cp production.tmpl production
vi production

# setup certificates:
ansible-playbook -i production k8s-mgmt.yml
# This has to be done only once per cluster!
# Delete or move CONTROL_BASE_DIR to reset and recreate all certificates.

# setup master(s)
ansible-playbook -i production k8s-master.yml

# setup nodes
ansible-playbook -i production k8s-node.yml

# setup loadbalancer (requires valid certificates for k8s domain namespace)
ansible-playbook -i production k8s-lb.yml
```

# Requirements

* Debian 9.1 or higher on the remote machines (you can use the [recipe](util/CreateVMImage.md) to create a VM image against which these scripts have been tested).
* Running sshd on the remote machines and on the control machine (preferrably localhost) and the package python-dnspython
* Pub key in .ssh/authorized\_keys in roots's home on the remote machines
* Python > 2.6
* Ansible >= 2.4.2.0 (on the control machine, only linux distros are supported!)
* All nodes must have valid DNS-Records (configured in production). IP-Addresses are no longer supported.
  If this condition is not fulfilled the k8s-mgmt.yml-playbook will fail.
* Two private network interfaces for k8s-nodes and k8s-master. Two private and one public interface for load balancer nodes.
* The playbooks assume the following order: First interface = sshd listening interface, Second interface = OVN overlay network interface and (for load balancer nodes): Third interface = internet endpoint)

Interface setup (iface1-2 are private interfaces, iface3 is public):
```
      +--------------+
      |k8s-master    |
      +--------------+
      |              |
SSH+--+    iface1    |
      |    iface2    +----+
      |              |    |
      +--------------+    |
                          |
      +--------------+    |
      |k8s-node(s)   |    |
      +--------------+    |
      |              |    |
SSH+--+    iface1    |    |
      |    iface2    +---OVN (hijacked)
      |              |    |
      +--------------+    |
                          |
      +--------------+    |
      |k8s-lb        |    |
      +--------------+    |
      |              |    |
SSH+--+    iface1    |    |
      |    iface2    +----+          +------------+
      |    iface3    +---------------+  Internet  |
      |              |               +------------+
      +--------------+
```
Created using: http://asciiflow.com/
# Documentation

## Role Overview
Note: For readability purposes, not in order of execution!

|  k8s-management-machine             |  k8s-master                |  k8s-node                  |  k8s-lb      |
|:-:	                |:-:	                     |:-:	                      |:-:	         |
| cert-infrastructure  	| vmware-node OR nebula-node | vmware-node OR nebula-node | apache-proxy |
|  	                    | common                     | common                     |              |
|  	                    | ufw  	                     | ufw            	          |   	         |
|  	                    | docker  	                 | docker         	          |   	         |
|  	                    | k8s-binaries  	         | k8s-binaries  	          |   	         |
|  	                    | kubelet  	                 | kubelet        	          |   	         |
|  	                    | kube-proxy  	             | kube-proxy     	          |   	         |
|                   	| network\_ovn               | network\_ovn               |   	         |
|  	                    | k8s-cordon  	             | k8s-cordon                 |   	         |
|  	                    | apiserver  	             |                            |              |
|                   	| scheduler  	             |                            |              |
|  	                    | controller-manager  	     |                            |   	         |
|  	                    | etcd  	                 |                            |              |
|  	                    | [k8s-addons](#markdown-header-k8s-addons)  	             |                            |              |
|  	                    | [cni](#markdown-header-cni)  	                     |                            |              |



## Role Descriptions

### apache-proxy

Handles the setup of the SSL termination infrastructure involving an apache proxy webserver.

### apiserver

The apiserver is the management interface of the k8s cluster.
You can choose to run the apiserver as a systemd-service (set APISERVER\_AS\_SERVICE to "True") or as a pod (APISERVER\_AS\_POD to "True"). At least and at most one of these options has to be true.

### cert-infrastructure

This role creates a ca ready infrastructure on a trusted host the localhost should be the default.
To get it working you'll have to set the following variables in group\_vars/all:
* CONTROL\_MACHINE:    Trusted machine on which certificates are issued and ca's private key resides (set "127.0.0.1" for localhost)
* CONTROL\_BASE\_DIR: Directory in which certficate infrastructure is persisted.

These subdirs shouldn't be altered in group\_vars/all template (they are here for documentation purpose.
* CONTROL\_CERT\_DIR: All certificates reside here (including certification authority certificate) (Default: CONTROL\_BASE\_DIR/certs).
* CONTROL\_KEY\_DIR: All keys reside here (including private key of certification authority)( Default: CONTROL\_BASE\_DIR/keys).
* CONTROL\_CONFIG\_DIR: Openssl configs reside here (Default:  CONTROL\_BASE\_DIR/configs).
* CONTROL\_CSR\_DIR: Certificate Signing requests reside here (Default: CONTROL\_BASE\_DIR/csrs).
* CONTROL\_CA\_DIR:  Certification Authority Management files reside here (e.g. serial numbers, issued certificates, etc.) (Default: CONTROL\_BASE\_DIR/ca"

It also creates a number of certificates (both server and client) to handle authorization inside the k8s cluster (e.g. etcd <-> apiserver).

### common

This role sets up all machines (install packages, set hostname, create directories etc.).

### controller-manager

The controller-manager runs on all master instances and distributes the deployments and pods to the kubelets running on the node instances.

You can choose to run the controller-manager as a systemd-service (set CONTROLER\_MANAGER\_AS\_SERVICE to "True") or as a pod (CONTROLER\_MANAGER\_AS\_POD to "True"). At least and at most one of these options has to be true.

### cni

This role handles the setup of the network cni plugin used by kubernetes.

### docker

Docker is the container engine running on both the nodes and the master.

### etcd

Etcd is a distributed key-value store to persist the k8s configuration serviced by the apiserver. It is also used to synchronize several masters (and therefore several apiservers).

### k8s-addons

This role sets up the kubernetes addon manager and handles the creation of the kube-dns service.

### k8s-binaries

This role fetches the kubernetes binaries in a version defined by K8S\_VERSION.
It also creates a kubeconfig that is used system wide to configure the k8s components with the whereabouts of and the credentials to the other components

### k8s-cordon

This role makes sure that the kubernetes master and loadbalancer are excluded from having pods scheduled upon them.

### kubelet

The kubelet component is the interface to the docker daemon which makes sure the Deployments and Pods are translated into running docker containers.
Kubelet will run as a systemd-service on all node and master instances.

### kube-proxy

The kube-proxy takes care of proxying request inside the k8s cluster.
Kube-proxy will run a s systemd-service on all nodes.

### network\_ovn

OVN/OVS is one of the possible k8s network driver (see [k8s network model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model). All additional network driver should be named alongside the pattern network\_*.

### scheduler

The scheduler runs scheduled pods.
You can choose to run the scheduler as a systemd-service (set SCHEDULER\_AS\_SERVICE to "True") or as a pod (SCHEDULER\_AS\_POD to "True"). At least and at most one of these options has to be true.

### ufw

This role sets up the uncomplicated firewall (ufw). Depending on which node it's executed on it will vary the port openings, for example the load balancer will receive additional openings at 80 and 443. 

# CI

The repository is now checked by a CI-Task in Bamboo (push to bitbucket)

# Other Playbooks

## k8s-nibi.yml

This playbook makes sure the latest GeRDI version is deployed on a cron basis

This playbook will only work if a file "registry_config" is on the root of the system (needed to seed the registry credentials as a secret to k8s). See [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/).
