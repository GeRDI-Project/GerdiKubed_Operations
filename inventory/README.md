# How to Configure the Ansible Inventory to Deploy a Kubernetes Cluster

This README describes how a user has to adjust the ansible inventory files in order to deploy a full kubernetes (k8s)
cluster on a linux infrastructure. Such a deployment required the installation and configuration of many individual
components. Most of them are configured automatically. However, a few input variables are required. In order to keep
the configuration files short and readable, they were split into multiple files which can be found in the 
group_vars/all directory.

- common.yml        : Contains common configurations
- kubernetes.yml    : Contains configurations and variables which are agnostic to k8s
- networking.yml    : Configurations for the cluster networking
- storage.yml       : Configurations of the NFS storage backend
- monitoring.yml    : Configuration of the Prometheus/Grafana based Monitoring system
- secrets.yml       : Configuration parameters which have to be encrypted

Values which are outcommented own a respective default variables which is defined in the according role and shown in
the configuration template file.

## Requirements

This playbooks have been tested on virtual maschines which run Debian 9. We don't guarantee that the playbooks will
run on any other operating system as well as on infrastructers other than OpenStack or VMWare. In order to run the
playbooks a recent version of Ansible (>=2.9) is required.

- One host that acts as a loadbalancer/gateway to the k8s cluster network
- One host that acts as the k8s master and api server. In addition this node runs the etcd key-value store
- A least one further hosts that acts as a k8s compute node.

## Maintainer

- Alexander Götz (2019-)
