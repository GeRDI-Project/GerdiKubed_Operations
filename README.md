# GerdiKubed

This repo has all necessary roles to setup a kubernetes cluster (req. see below).

There are three playbooks in the root of the git-repo:
* k8s-master.yml
* k8s-nodes.yml
* k8s-mgmt.yml

# Usage

```bash
# setup certificates
ansible-playbook -i production k8s-mgmt.yml

# setup master
ansible-playbook -i production k8s-master.yml

# setup nodes
ansible-playbook -i production k8s-nodes.yml -K
```

# Requirements

* debian 9.1 or higher on the remote machines
* running sshd on the remote machines
* pub key in .ssh/authorized_keys in roots's home on the remote machines
* python > 2.6
* ansible >= 2.4.1.0 (on the control machine, only linux distros are supported!)
* iproute2 installed
* at least two network interface for k8s-ndes


# CI

The repository is now checked by a CI-Task in Bamboo (push to bitbucket)
