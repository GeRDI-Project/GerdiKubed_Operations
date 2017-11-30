# GerdiKubed

This repo has all necessary roles to setup a kubernetes cluster (req. see below).

There are three playbooks in the root of the git-repo:
* k8s-master.yml
* k8s-nodes.yml
* k8s-mgmt.yml

# Usage

```bash

# Edit variable-template (see role documentation for questions):
cp group_var/all.tmpl group_var/all
vi group_var/all

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
ansible-playbook -i production k8s-nodes.yml -K
```

# Requirements

* Debian 9.1 or higher on the remote machines (you can use the [recipe](CreateVMImage.md) to create a VM image against which these scripts have been tested).
* Running sshd on the remote machines and on the control machine (preferrably localhost)
* Pub key in .ssh/authorized\_keys in roots's home on the remote machines
* Python > 2.6
* Ansible >= 2.4.1.0 (on the control machine, only linux distros are supported!)
* On nodes: iproute2 (if you forget and k8s-nodes.yml fail, rerun them)
* at least two network interface for k8s-nodes
* There needs to be one interface named ens3 that holds an IP adress und which the services are reachable. This must not be the ovn-management interface. Sometime the name of the interface should somehow be dynamically determined - now it is hardcoded in two roles (kubelet and network\_ovn)

# Documentation

## Roles

### apiserver

The apiserver is the management interface to the k8s cluster.

You can choose to run the apiserver as a systemd-service (set APISERVER\_AS\_SERVICE to "True") or as a pod (APISERVER\_AS\_POD to "True"). At least and at most one of these options has to be true.

### cert-infrastructure

This role creates a ca ready infrastructure on a trusted host the localhost should be the default.

To get it working you'll have to set the following variables in group\_var/all:
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

### docker

Docker is the container engine running on both the nodes and the master.

### etcd

Etcd is a distributed key-value store to persist the k8s configuration serviced by the apiserver. It is also used to synchronize several masters (and therefore several apiservers).

### k8s-binaries

This role fetches the kubernetes binaries in a version defined by K8S\_VERSION.

It also creates a kubeconfig that is used system wide to configure the k8s components with the whereabouts of and the credentials to the other components

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

# CI

The repository is now checked by a CI-Task in Bamboo (push to bitbucket)
