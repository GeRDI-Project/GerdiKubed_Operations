
# GerdiKubed

This repo has all necessary roles to setup a kubernetes cluster (req. see below).
There are multiple playbooks in the root of the git repository:

*Note: In order of execution!*

* k8s-mgmt.yml
* (k8s-nfs.yml; *Optional*)
* k8s-master.yml
* k8s-node.yml
* k8s-lb.yml
* k8s-stack.yml
* (k8s-gerdi.yml; *Optional*)

## Usage

```bash
# Initial setup
# Create new inventory from template:
cp -r inventory/dev.gerdi.research.lrz.de inventory/<deployment-context>

# Edit inventory (hosts.ini) and group variables (group_vars/all.yml):
# (Consult role documentation for variable descriptions)
vi inventory/<deployment-context>/hosts.ini
vi inventory/<deployment-context>/group_vars/all.yml

# ----------------------------------------------------------------------#

# Ansible execution:
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

## Requirements

* Debian 9.1 or higher on the remote machines (you can use the [recipe](util/CreateVMImage.md) to create a VM image against which these scripts have been tested).
* Running sshd on the remote machines and on the control machine (preferrably localhost) and the package python-dnspython
* Pub key in .ssh/authorized\_keys in roots's home on the remote machines
* Python > 2.6
* Ansible >= 2.8.0.0 (on the control machine, only linux distros are supported!)
* All nodes must have valid DNS-Records (configured in production). IP addresses are no longer supported. If this condition is not fulfilled the k8s-mgmt.yml-playbook will fail.
* Nodes must follow the following network interface setup:
  * One *private* network interface for nfs-nodes, k8s-nodes and k8s-master.
  * One *private* and one *public* network interface for loadbalancer nodes.
* The playbooks assume the following order:
  * First interface (private): sshd listening & OVN overlay network interface
  * Second interface (public): Internet endpoint (loadbalancer only)

**Cluster Setup:**

```Text
  Private Network
+-------------------------------------------------------------------------------------------+
|                                                                                           |
|                                       +--------------+                                    |
|                                       |  k8s master  +-------+NFS+----+                   |
|                                       +--------------+                |                   |
|                                       |              |                |                   |
|                           +----+SSH+--+    iface1    +---+            |                   |
|                           |           |              |   |            |                   |
|                           |           |              |   |            |    +------------+ |
|                           |           +--------------+   |            |    | nfs server | |
|                           |                              |            |    +------------+ |
| +-------------------+     |           +--------------+   |            +    |            | |
| |  Control Machine  |     |           |  k8s node(s) +-------+NFS+-+Mount+-+   iface1   | |
| +-------------------+     |           +--------------+   |            +    |            | |
| |                   |     +           |              |   +            |    |            | |
| |      iface1       +-+Ansible++SSH+--+    iface1    +-+OVN           |    +------------+ |
| |                   |     +           |              |   +            |                   |
| |                   |     |           |              |   |            |                   |
| +-------------------+     |           +--------------+   |            |                   |
|                           |                              |            |                   |
|                           |           +--------------+   |            |                   |
|                           |           |    k8s lb    +-------+NFS+----+                   |
|                           |           +--------------+   |                                |
|                           |           |              |   |                                |
|                           +----+SSH+--+    iface1    +---+                                |
|                                       |              |                                    |
+-------------------------------------------------------------------------------------------+
                                        |              |
                                        |              |               +------------+
                                        |    iface2    +---------------+  Internet  |
                                        |              |               +------------+
                                        +--------------+
```

Created using: http://asciiflow.com/

## Documentation

The documentation in this README is only a very limited. Further documentation can be found in the [docs](docs)
directory, which also contains specific instructions for usage with different private cloud providers that have
in the according role directory.
been tested during the development process. For each role, the documentation can be found in the README.md file

### Tags

`--skip-tags <tags>` option. The following example shows the usage for the k8s-lb playbook, skipping the deployment
specifically trigger the execution of certian tasks. To skipt roles which hold a certain tag you can use the 
In order to allows certain deployment and update mechanisms, tags are used in the notebooks in order to prevent or
of ne certificate files.

```bash
ansible-playbook -i inventory/<deployment-context>/hosts.ini --skip-tags certs k8s-lb.yml
```

All available tags, their functionality and occurences are listed in the following table

| Tag | Description |
|---|---|
| cert | Skips deployment of certificate files to k8s hosts |

### Role Overview

*Note: For readability purposes, not in order of execution!*

|&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Playbook<br>Role <br>  |  k8s-master |  k8s-node  |  k8s-lb  |  k8s-mgmt |  k8s-nfs  |  k8s-stack  |  k8s-gerdi  |
|---|---|---|---|---|---|---|---|
| [vmware-node](#vmware-node) OR <br> [openstack-node](#openstack-node) |<div align="center">x</div>|      <div align="center">x</div>      |      |      |      |      |      |
| [network-interfaces](#network-interfaces)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [common](#common)|      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [ufw](#ufw)|      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [docker](#docker)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [k8s-binaries](#k8s-binaries)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [kube-proxy](#kube-proxy)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [kubelet](#kubelet)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [network-ovn](#network-ovn)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [k8s-cordon](#k8s-cordon)      |      <div align="center">x</div>      |      <div align="center">x</div>      |      |      |      |      |      |
| [scheduler](#scheduler)      |      <div align="center">x</div>      |      |      |      |      |      |      |
| [controller-manager](#controller-manager)  |      <div align="center">x</div>      |      |      |      |      |      |      |
| [apiserver](#apiserver)      |      <div align="center">x</div>      |      |      |      |      |      |      |
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

### Role Descriptions

<a name="apache-proxy"></a>

### apache-proxy

Handles the setup of the SSL termination infrastructure involving an apache proxy webserver.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```MAIN_DOMAIN``` | www.```K8S_DEPLOYMENT_CONTEXT```.<br>```K8S_DOMAIN_NAMESPACE``` | apache.conf: ServerName |
| ```OTHER_DOMAIN``` | ```K8S_DEPLOYMENT_CONTEXT```.<br>```K8S_DOMAIN_NAMESPACE``` | apache.conf: AlternativeName<br> (Can be more than one) |

<a name="apiserver"></a>

### apiserver

The apiserver is the management interface of the k8s cluster. It runs on the k8s-master node as a systemd-service.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```CONTROL_BASE_DIR``` | ~ | Directory in which certificate infrastructure is persisted. |
| ```CONTROL_KEY_DIR``` | ```CONTROL_BASE_DIR```/keys | All keys reside here (including private key of CA) |
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```K8S_MASTER_DOMAIN``` | 'mstr-0.' + ```K8S_DEPLOYMENT_CONTEXT``` + '.' + ```K8S_DOMAIN_NAMESPACE``` | Domain of master |
| ```K8S_MASTER_IP``` | hostvars[```K8S_MASTER_DOMAIN```]['altIP'] \|<br> default(lookup('dig', ```K8S_MASTER_DOMAIN```)) | IP of the master, will default to a DNS lookup if no "altIP" given |
| ```K8S_AUTH_FILES_DIR``` | ```K8S_BASE_DIR```/tokens | Kubernetes cluster token location |
| ```K8S_CERT_FILES_DIR``` | ```K8S_BASE_DIR```/certs | Kubernetes cluster certificate location |
| ```K8S_KEY_FILES_DIR``` | ```K8S_BASE_DIR```/keys | Kubernetes cluster keys location |
| ```K8S_SERVER_BIN_DIR``` | ```K8S_K8S_DIR```/server/kubernetes/server/bin | Location of Kubernetes server binary |
| ```K8S_SERVICE_IP_PRE``` | 10.222 | IP Prefix of Kubernetes services subnet |
| ```K8S_SERVICE_IP_SUBNET``` | ```K8S_SERVICE_IP_PRE```.0.0/16 | Kubernetes services subnet |
| ```K8S_GLOBAL_LOG_LEVEL``` | "v=1" | Kubernetes apiserver verbosity |

<a name="cert-infrastructure"></a>

### cert-infrastructure

This role creates a CA ready infrastructure on a trusted host, the localhost should be the default.
To get it working you'll have to set the following variables in group\_vars/all:

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```CONTROL_MACHINE``` | 127.0.0.1 | Trusted machine on which certificates are issued and CA's private key resides |
| ```CONTROL_BASE_DIR``` | ~ | Directory in which certificate infrastructure is persisted. |

*The following subdirs shouldn't be altered in the group\_vars/all template, they are there for documentation purpose:*

| Name | Default Value | Description |
|---|---|---|
| ```CONTROL_CERT_DIR``` | ```CONTROL_BASE_DIR```/certs | All certificates reside here (including CA certificate) |
| ```CONTROL_KEY_DIR``` | ```CONTROL_BASE_DIR```/keys | All keys reside here (including private key of CA) |
| ```CONTROL_CONFIG_DIR``` | ```CONTROL_BASE_DIR```/configs | OpenSSL configs reside here |
| ```CONTROL_CSR_DIR``` | ```CONTROL_BASE_DIR```/csrs | Certificate Signing requests reside here |
| ```CONTROL_CA_DIR``` | ```CONTROL_BASE_DIR```/ca | Certification Authority Management files reside here (e.g. serial numbers, issued certificates, etc.) |

It also creates a number of certificates (both server and client) to handle authorization inside the k8s cluster (e.g. *etcd* <=> *apiserver*).

<a name="common"></a>

### common

This role sets up all machines (install packages & certificates, creates directories etc.).

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```CONTROL_BASE_DIR``` | ~ | Directory in which certificate infrastructure is persisted. |
| ```CONTROL_CERT_DIR``` | ```CONTROL_BASE_DIR```/certs | All certificates reside here (including CA certificate) |
| ```CONTROL_KEY_DIR``` | ```CONTROL_BASE_DIR```/keys | All keys reside here (including private key of CA) |
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```K8S_AUTH_FILES_DIR``` | ```K8S_BASE_DIR```/tokens | Kubernetes cluster token location |
| ```K8S_CERT_FILES_DIR``` | ```K8S_BASE_DIR```/certs | Kubernetes cluster certificate location |
| ```K8S_KEY_FILES_DIR``` | ```K8S_BASE_DIR```/keys | Kubernetes cluster keys location |
| ```NFS_SERVER_DOMAIN``` | nfs.```K8S_DEPLOYMENT_CONTEXT```.<br>```K8S_DOMAIN_NAMESPACE``` |  FQDN of the NFS server |
| ```NFS_VOLUME_PATH``` | /intern/gerdi01 | Path of the to be mounted directory on the NFS server |
| ```NFS_MOUNT_PATH``` | /mnt/nfs | Path to be mounted to on the node |

<a name="controller-manager"></a>

### controller-manager

The controller-manager runs on all master instances as a systemd-service and distributes the deployments and pods to the kubelets running on the node instances.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```CONTROL_BASE_DIR``` | ~ | Directory in which certificate infrastructure is persisted. |
| ```CONTROL_KEY_DIR``` | ```CONTROL_BASE_DIR```/keys | All keys reside here (including private key of CA) |
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_CERT_FILES_DIR``` | ```K8S_BASE_DIR```/certs | Kubernetes cluster certificate location |
| ```K8S_KEY_FILES_DIR``` | ```K8S_BASE_DIR```/keys | Kubernetes cluster keys location |
| ```K8S_KUBECONFIG``` | ```K8S_BASE_DIR```/kubeconfig | Kubernetes kubeconfig location |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_SERVER_BIN_DIR``` | ```K8S_K8S_DIR```/server/kubernetes/server/bin | Location of Kubernetes server binary |
| ```K8S_CLUSTER_IP_PRE``` | 10.220 | IP Prefix of Kubernetes pods subnet |
| ```K8S_CLUSTER_IP_SUBNET``` | ```K8S_CLUSTER_IP_PRE```.0.0/15 | Kubernetes pods subnet |
| ```K8S_GLOBAL_LOG_LEVEL``` | "v=1" | Kubernetes controller manager verbosity |

<a name="cluster-dns"></a>

### cluster-dns

Sets up dnsmasq and forces the loadbalancer to use kube-dns to resolve cluster internal domains.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_SERVICE_IP_PRE``` | 10.222 | IP Prefix of Kubernetes services subnet |
| ```K8S_SERVICE_IP_SUBNET``` | ```K8S_SERVICE_IP_PRE```.0.0/16 | Kubernetes services subnet |
| ```K8S_DNS_IP``` | ```K8S_SERVICE_IP_PRE```.0.10 | kube-dns service IP |

<a name="cni"></a>

### cni

This role handles the setup of the network cni plugin used by kubernetes.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```CNI_VERSION``` | v0.5.2 | CNI version |
| ```CNI_DIR``` | ```K8S_BASE_DIR```/cni-```CNI_VERSION``` | CNI binary location |
| ```CNI_CONF_DIR``` | /etc/cni/net.d | CNI config location|
| ```CNI_DOWNLOAD_URL``` | https://github.com/containernetworking/cni/releases/download/<br>```CNI_VERSION```/cni-```CNI_VERSION```.tgz | CNI binary download URL |

<a name="docker"></a>

### docker

Docker is the container engine running on both the nodes and the master.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```DOCKER_VERSION``` | 5:18.09.1~3-0~debian-stretch | Docker version to install, must be a valid apt package |
| ```NODE_NAMESERVER``` | 1.1.1.1 | Nameserver the node (systemd-resolved) should use |
| ```DOCKER_NAMESERVER``` | ```NODE_NAMESERVER``` | The nameserver docker should use to resolve domains |
| ```NETWORK_MTU``` | 1500 | Adapts software MTUs incase of local network limitation |
| ```DOCKER_MTU``` | ```NETWORK_MTU``` | The MTU docker containers should utilize. If undefined, defaults to 1500 |

<a name="etcd"></a>

### etcd

Etcd is a distributed key-value store to persist the k8s configuration serviced by the apiserver. It is also used to synchronize several masters (and therefore several apiservers).

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```ETCD_VERSION``` | v3.0.17 | Etcd version to install |
| ```ETCD_DOWNLOAD_URL``` | https://github.com/coreos/etcd/releases/download/ ```ETCD_VERSION```/etcd-```ETCD_VERSION```-linux-amd64.tar.gz | Etcd download URL |
| ```ETCD_DIR``` | ```K8S_BASE_DIR```/etcd-```ETCD_VERSION```-linux-amd64 | Etcd installation directory |

<a name="helm"></a>

### helm

TBA

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```HELM_BASE_DIR``` | /opt/helm | Helm base directory |
| ```HELM_VERSION``` | v2.12.0 | Helm version to install |
| ```HELM_DOWNLOAD_URL``` | https://storage.googleapis.com/kubernetes-helm/helm-```HELM_VERSION```-linux-amd64.tar.gz | Helm download URL |

<a name="jhub"></a>

### jhub

TBA

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```JHUB_REPO``` | https://jupyterhub.github.io/helm-chart/ | Jhub git repository |
| ```JHUB_RELEASE``` | jhub | TBA |
| ```JHUB_NAMESPACE``` | jhub | TBA |
| ```JHUB_VERSION``` | 0.8.0 | Jhub version |
| ```JHUB_CONFIG``` | /root/jhub-chart.yml | Path to jhub config |

<a name="k8s-addons"></a>

### k8s-addons

This role sets up the kubernetes addon manager and handles the creation of the kube-dns service.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_KUBECONFIG``` | ```K8S_BASE_DIR```/kubeconfig | Kubernetes kubeconfig location |
| ```K8S_CLUSTER_IP_PRE``` | 10.220 | IP Prefix of Kubernetes pods subnet |
| ```K8S_SERVICE_IP_PRE``` | 10.222 | IP Prefix of Kubernetes services subnet |
| ```K8S_DNS_IP``` | ```K8S_SERVICE_IP_PRE```.0.10 | kube-dns service IP |

<a name="k8s-binaries"></a>

### k8s-binaries

This role fetches the kubernetes binaries in a version defined by K8S\_VERSION.
It also creates a kubeconfig that is used system wide to configure the k8s components with the whereabouts of and the credentials to the other components

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_DOWNLOAD_URL``` | https://github.com/kubernetes/kubernetes/releases/<br>download/```K8S_VERSION```/kubernetes.tar.gz | Kubernetes download url |
| ```K8S_SERVER_BIN_DIR``` | ```K8S_K8S_DIR```/server/kubernetes/server/bin | Location of Kubernetes server binary |
| ```K8S_KUBECONFIG``` | ```K8S_BASE_DIR```/kubeconfig | Kubernetes kubeconfig location |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```K8S_MASTER_DOMAIN``` | 'mstr-0.' + ```K8S_DEPLOYMENT_CONTEXT``` + '.' + ```K8S_DOMAIN_NAMESPACE``` | Domain of master |
| ```K8S_MASTER_IP``` | hostvars[```K8S_MASTER_DOMAIN```]['altIP'] \|<br> default(lookup('dig', ```K8S_MASTER_DOMAIN```)) | IP of the master, will default to a DNS lookup if no "altIP" given |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_CERT_FILES_DIR``` | ```K8S_BASE_DIR```/certs | Kubernetes cluster certificate location |
| ```K8S_KEY_FILES_DIR``` | ```K8S_BASE_DIR```/keys | Kubernetes cluster keys location |

<a name="k8s-cordon"></a>

### k8s-cordon

This role makes sure that the kubernetes master and loadbalancer are excluded from having pods scheduled upon them.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_KUBECONFIG``` | ```K8S_BASE_DIR```/kubeconfig | Kubernetes kubeconfig location |

<a name="keycloak"></a>

### keycloak

TBA

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```KEYCLOAK_BASEPATH``` | admin/auth | TBA |

<a name="kubelet"></a>

### kubelet

The kubelet component is the interface to the docker daemon which makes sure the Deployments and Pods are translated into running docker containers. Kubelet runs as a systemd-service on all node and master instances.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_SERVER_BIN_DIR``` | ```K8S_K8S_DIR```/server/kubernetes/server/bin | Location of Kubernetes server binary |
| ```K8S_KUBECONFIG``` | ```K8S_BASE_DIR```/kubeconfig | Kubernetes kubeconfig location |
| ```K8S_GLOBAL_LOG_LEVEL``` | "v=1" | Kubernetes controller manager verbosity |
| ```K8S_KEY_FILES_DIR``` | ```K8S_BASE_DIR```/keys | Kubernetes cluster keys location |
| ```K8S_CERT_FILES_DIR``` | ```K8S_BASE_DIR```/certs | Kubernetes cluster certificate location |
| ```K8S_DNS_IP``` | ```K8S_SERVICE_IP_PRE```.0.10 | kube-dns service IP |
| ```CNI_VERSION``` | v0.5.2 | CNI version |
| ```CNI_DIR``` | ```K8S_BASE_DIR```/cni-```CNI_VERSION``` | CNI binary location |
| ```CNI_CONF_DIR``` | /etc/cni/net.d | CNI config location|

<a name="kube-proxy"></a>

### kube-proxy

The kube-proxy takes care of proxying requests inside the k8s cluster. It runs as a systemd-service on all nodes.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_GLOBAL_LOG_LEVEL``` | "v=1" | Kubernetes controller manager verbosity |
| ```K8S_CLUSTER_IP_PRE``` | 10.220 | IP Prefix of Kubernetes pods subnet |
| ```K8S_CLUSTER_IP_SUBNET``` | ```K8S_CLUSTER_IP_PRE```.0.0/15 | Kubernetes pods subnet |
| ```K8S_SERVER_BIN_DIR``` | ```K8S_K8S_DIR```/server/kubernetes/server/bin | Location of Kubernetes server binary |

<a name="secrets"></a>

### secrets

TBA

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_KUBECONFIG``` | ```K8S_BASE_DIR```/kubeconfig | Kubernetes kubeconfig location |

<a name="network-interfaces"></a>

### network-interfaces

Sets up systemd-networkd & systemd-resolved by *'hotswapping'* the default networking.service (/etc/interfaces). Configures nameservers and network interfaces' properties to correctly fall in line with expectations of subsequent roles.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```host_private_rtable``` | 1337 | Identifier for private interface routing table |
| ```NODE_NAMESERVER``` | 1.1.1.1 | Nameserver the node (systemd-resolved) should use |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```NFS_SERVER_DOMAIN``` | nfs.```K8S_DEPLOYMENT_CONTEXT```.<br>```K8S_DOMAIN_NAMESPACE``` |  FQDN of the NFS server |

<a name="nfs-server"></a>

### nfs-server

Responsible for setting up a NFS server alongside the k8s cluster and adding all nodes from the cluster to its' exports file. This is optional, you can also choose to pick an already existing external NFS server.

*Note: If you add additional nodes to the cluster, you have to execute this playbook again to add the new nodes to the exports. This will override manually added hosts!*

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```nfs_server_daemon``` | nfs-kernel-server | NFS service name |
| ```NFS_VOLUME_PATH``` | /intern/gerdi01 | Path of the to be mounted directory on the NFS server |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |

<a name="network-ovn"></a>

### network-ovn

OVN/OVS is one of the possible k8s network driver (see [k8s network model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model)). This role sets up a geneve interface to tunnel and encrypt pod to pod traffic.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```OVN_API_TOKEN``` | someValue | OVN authentification token |
| ```OVN_ENCAP_TYPE``` | geneve | OVN encapsulation mode |
| ```OPENVSWITCH_VERSION``` | 2.10.0+2018.08.28+git.8ca7c82b7d+ds1-12 | OVN version to install |
| ```OVN_HOST_VERSION``` | ```OPENVSWITCH_VERSION``` | OVN version to install on nodes |
| ```OVN_CENTRAL_VERSION``` | ```OPENVSWITCH_VERSION``` | OVN version to install on master |
| ```OVN_MTU``` | (( ```NETWORK_MTU``` \| int) - 100) \| int \| abs | OVN MTU, always 100 bytes less than ```NETWORK_MTU``` |
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```OVN_K8S_DIR``` | ```K8S_BASE_DIR```/ovn-kubernetes | OVN installation location |
| ```K8S_CERT_FILES_DIR``` | ```K8S_BASE_DIR```/certs | Kubernetes cluster certificate location |
| ```K8S_CLUSTER_IP_PRE``` | 10.220 | IP Prefix of Kubernetes pods subnet |
| ```K8S_CLUSTER_IP_SUBNET``` | ```K8S_CLUSTER_IP_PRE```.0.0/15 | Kubernetes pods subnet |
| ```K8S_SERVICE_IP_PRE``` | 10.222 | IP Prefix of Kubernetes services subnet |
| ```K8S_SERVICE_IP_SUBNET``` | ```K8S_SERVICE_IP_PRE```.0.0/16 | Kubernetes services subnet |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```K8S_MASTER_DOMAIN``` | 'mstr-0.' + ```K8S_DEPLOYMENT_CONTEXT``` + '.' + ```K8S_DOMAIN_NAMESPACE``` | Domain of master |
| ```K8S_MASTER_IP``` | hostvars[```K8S_MASTER_DOMAIN```]['altIP'] \|<br> default(lookup('dig', ```K8S_MASTER_DOMAIN```)) | IP of the master, will default to a DNS lookup if no "altIP" given |
| ```CNI_VERSION``` | v0.5.2 | CNI version |
| ```CNI_DIR``` | ```K8S_BASE_DIR```/cni-```CNI_VERSION``` | CNI binary location |
| ```GOLANG_VERSION``` | go1.12.4 | Go language version to install |

<a name="persistent-volumes"></a>

### persistent-volumes

TBA

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```NFS_SERVER_DOMAIN``` | nfs.```K8S_DEPLOYMENT_CONTEXT```.<br>```K8S_DOMAIN_NAMESPACE``` |  FQDN of the NFS server |
| ```NFS_VOLUME_PATH``` | /intern/gerdi01 | Path of the to be mounted directory on the NFS server |

<a name="prometheus"></a>

### prometheus

Installs the prometheus monitoring system for central cluster and service monitoring. Prometheus [prometheus.io](https://prometheus.io/) is the default monitoring system for kubernetes and is maintained
by the Cloud Native Foundation. It provides time series related monitoring and alerting. The role creates a dedicated kube-monitor namespace and deploys the prometheus master server into it.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```PROMETHEUS_BASE_DIR``` | /opt/prometheus |   Prometheus installation directory |
| ```PROMETHEUS_SERVER_VERSION``` | 2.9.1 | Prometheus server version |
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_DEPLOYMENT_CONTEXT``` | dev | Name of the cluster |
| ```K8S_DOMAIN_NAMESPACE``` | gerdi.research.lrz.de | domain name of the cluster |
| ```MAIN_DOMAIN``` | www.```K8S_DEPLOYMENT_CONTEXT```.<br>```K8S_DOMAIN_NAMESPACE``` | apache.conf: ServerName |

<a name="scheduler"></a>

### scheduler

The scheduler runs scheduled pods. It operates on the k8s-master as a systemd-service.

**Variables:**

| Name | Default Value | Description |
|---|---|---|
| ```K8S_BASE_DIR``` | /opt/k8s | Kubernetes base directory |
| ```K8S_SERVER_BIN_DIR``` | ```K8S_K8S_DIR```/server/kubernetes/server/bin | Location of Kubernetes server binary |

<a name="ufw"></a>

### ufw

This role sets up the uncomplicated firewall (ufw). Depending on which node it's executed on, it will vary the port openings, for example the loadbalancer will receive additional openings at TCP/80 and TCP/443.

## Node Specific Roles

<a name="vmware-node"></a>

### vmware-node

This role is tailored to VMware machines running on LRZ infrastructure. Depending on the node, different steps have to be performed to bring each node into a state that allows the subsequent roles to be executed properly.

<a name="openstack-node"></a>

### openstack-node

This role is tailored to Openstack machines running on LRZ infrastructure. It features support for floating IPs and security groups. Depending on the node, different steps have to be performed to bring each node into a state that allows the subsequent roles to be executed properly.

# CI

The repository is checked by a CI-Task in Bamboo (push to bitbucket). You can't merge a PR that wasn't build successfully!
