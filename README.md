# GerdiKubed

This repo has all necessary roles to setup a kubernetes cluster (req. see below).

There are three major playbooks in the root of the git-repo (for the others see below):
* k8s-master.yml
* k8s-nodes.yml
* k8s-mgmt.yml

## Usage

```bash

# Edit variable-template (consult role & version documentation (util/VariableTemplate.md) for answers):
cp group_vars/all.tmpl group_vars/all
vi group_vars/all

# Edit inventory file-template
cp production.tmpl production
vi production

# setup certificates:
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-mgmt.yml
# This has to be done only once per cluster!
# Delete or move CONTROL_BASE_DIR to reset and recreate all certificates.

# setup master(s)
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-master.yml

# setup nodes
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-node.yml

# setup loadbalancer (requires valid certificates for k8s domain namespace)
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-lb.yml

# Deploy the k8s stack for monitoring and management
ansible-playbook -i inventory/<deployment-context>/hosts.ini k8s-stack.yml
```

## Requirements

* Debian 9.1 or higher on the remote machines (you can use the [recipe](util/CreateVMImage.md) to create a VM image against which these scripts have been tested).
* Running sshd on the remote machines and on the control machine (preferrably localhost) and the package python-dnspython
* Pub key in .ssh/authorized\_keys in roots's home on the remote machines
* Python > 2.6
* Ansible >= 2.4.2.0 (on the control machine, only linux distros are supported!)
* All nodes must have valid DNS-Records (configured in production). IP-Addresses are no longer supported.
  If this condition is not fulfilled the k8s-mgmt.yml-playbook will fail.
* One private network interface for k8s-nodes and k8s-master. One private and one public interface for load balancer nodes.
* The playbooks assume the following order: First interface = SSHD listening & OVN overlay network interface (and for load balancer nodes: Second interface = internet endpoint)

Interface setup (iface1 is a private interface, iface2 is public):
```
      +--------------+
      |k8s|master    |
      +--------------+
      |              |
SSH+--+    iface1    +----+
      |              |    |
      |              |    |
      +--------------+    |
                          |
      +--------------+    |
      |k8s|node(s)   |    |
      +--------------+    |
      |              |    |
SSH+--+    iface1    +---OVN
      |              |    |
      |              |    |
      +--------------+    |
                          |
      +--------------+    |
      |k8s|lb        |    |
      +--------------+    |
      |              |    |
SSH+--+    iface1    +----+
      |              |               +------------+
      |    iface2    +---------------+  Internet  |
      |              |               +------------+
      +--------------+

```
Created using: http://asciiflow.com/

## Documentation

The documentation in this README is only a very limited. Further documentation can be found in the [docs](docs)
directory, which also contains specific instructions for usage with different private cloud providers that have
been tested during the development process. For each role, the documentation can be found in the README.md file
in the according role directory.

### Tags

In order to allows certain deployment and update mechanisms, tags are used in the notebooks in order to prevent or
specifically trigger the execution of certian tasks. To skipt roles which hold a certain tag you can use the 
`--skip-tags <tags>` option. The following example shows the usage for the k8s-lb playbook, skipping the deployment
of ne certificate files.

```bash

ansible-playbook -i inventory/<deployment-context>/hosts.ini --skip-tags certs k8s-lb.yml

```

All available tags, their functionality and occurences are listed in the following table


| Tag       | Description                                         |                         
| --------- | --------------------------------------------------- |
| cert      | Skips deployment of certificate files to k8s hosts  |

### Role Overview
Note: For readability purposes, not in order of execution!

| Role             							 |  k8s-master |  k8s-node  |  k8s-lb  |   k8s-management-machine |
|---	                					 |---	       |---	        |---	   |---						  |
| [vmware-node OR nebula-node](#vmware-node) |      x      |     x      |          |						  |
| [common](#common) 	                     |      x      |     x      |          |					      |
| [ufw](#ufw) 	                    		 |   	x      |     x   	|   	   |						  |
| [docker](#docker) 	                     |   	x      |     x   	|   	   |						  |
| [k8s-binaries](#k8s-binaries) 	         |   	x      | 	 x		| 		   |						  |
| [kubelet](#kubelet) 	                     |   	x      |	 x		|	   	   |						  |
| [kube-proxy](#kube-proxy) 	             |   	x      |     x	    |   	   |						  |
| [network-ovn](#network-ovn)               |      x      | 	 x		|   	   |						  |
| [k8s-cordon](#k8s-cordon) 	             |   	x      | 	 x		|   	   |						  |
| [apiserver](#apiserver)  	                 |  	x      |            |          |						  |
| [scheduler](#scheduler)                  	 |  	x      |            |          |						  |
| [controller-manager](#controller-manager)  |   	x      |            |   	   |						  |
| [etcd](#etcd)  	  	                     |      x      |            |          |						  |
| [k8s-addons](#k8s-addons)  	             |  	x      |            |          |						  |
| [cni](#cni)  	                    		 |  	x      |            |          |						  |
| [apache-proxy](#apache-proxy) 	         |             |            |    x     |						  |
| [cert-infrastructure](#cert-infrastructure)|  		   |  			|  		   |			x			  |

### Role Descriptions

<a name="apache-proxy"></a> 
### apache-proxy

Handles the setup of the SSL termination infrastructure involving an apache proxy webserver.

<a name="apiserver"></a> 
### apiserver

The apiserver is the management interface of the k8s cluster.
You can choose to run the apiserver as a systemd-service (set APISERVER\_AS\_SERVICE to "True") or as a pod (APISERVER\_AS\_POD to "True"). At least and at most one of these options has to be true.

<a name="cert-infrastructure"></a> 
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

<a name="common"></a> 
### common

This role sets up all machines (install packages, set hostname, create directories etc.).

<a name="controller-manager"></a> 
### controller-manager

The controller-manager runs on all master instances and distributes the deployments and pods to the kubelets running on the node instances.

You can choose to run the controller-manager as a systemd-service (set CONTROLER\_MANAGER\_AS\_SERVICE to "True") or as a pod (CONTROLER\_MANAGER\_AS\_POD to "True"). At least and at most one of these options has to be true.

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

The kubelet component is the interface to the docker daemon which makes sure the Deployments and Pods are translated into running docker containers.
Kubelet will run as a systemd-service on all node and master instances.

<a name="kube-proxy"></a> 
### kube-proxy

The kube-proxy takes care of proxying request inside the k8s cluster.
Kube-proxy will run a s systemd-service on all nodes.

<a name="network-ovn"></a> 
### network-ovn

OVN/OVS is one of the possible k8s network driver (see [k8s network model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model). All additional network driver should be named alongside the pattern network\_*.

<a name="prometheus"></a>
### prometheus

Install the prometheus monitoring system for central cluster and service monitoring. Prometheus [prometheus.io](https://prometheus.io/) is the default monitoring system for kubernetes and is maintained
by the Cloud Native Foundation. It provides time series related monitoring and alerting. The role creates a dedicated kube-monitor namespace and deploys the prometheus master server into it.

<a name="scheduler"></a> 
### scheduler

The scheduler runs scheduled pods.
You can choose to run the scheduler as a systemd-service (set SCHEDULER\_AS\_SERVICE to "True") or as a pod (SCHEDULER\_AS\_POD to "True"). At least and at most one of these options has to be true.

<a name="ufw"></a> 
### ufw

This role sets up the uncomplicated firewall (ufw). Depending on which node it's executed on it will vary the port openings, for example the load balancer will receive additional openings at 80 and 443. 

<a name="vmware-node"></a> 
### vmware-node OR nebula-node

These roles are both tailored to machines running on LRZ infrastructure. Depending on the node, different steps have to be performed to bring the cluster into a state that allows the other roles to be executed properly.

# CI

The repository is now checked by a CI-Task in Bamboo (push to bitbucket)
