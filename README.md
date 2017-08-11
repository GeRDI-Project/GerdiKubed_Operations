# GerdiKubed

This repo has all necessary roles to setup a kubernetes cluster (req. see below).

There are two playbooks in the root of the git-repo:
* kubernetes-master.yml
* kubernetes-nodes.yml

# Usage

```bash
# setup master
ansible-playbook -i production kubernetes-master.yml -K

# setup nodes
ansible-playbook -i production kubernetes-nodes.yml -K
```

# Requirements

If not stated explicitely, the requirements need to be fulfilled
by both the remote machines and the control machine:

* debian 9.1 or higher on the remote machines
* running sshd
* sudo
* user "gerdi" with sudo rights
* pub key in .ssh/authorized_keys in gerdi's home
* python > 2.6
* ansible > 2.3.1 (on the control machine, only macOS and linux distros are supported!)
* python-pyOpenSSL on the control machine (for cert-signing).

# CI

The repository is now checked by a CI-Task in Bamboo (push to bitbucket)
