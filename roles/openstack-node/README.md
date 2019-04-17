# openstack-node, Ansible Role for Base Configuration of an OpenStack Cloud VM

This is an ansible role for proper configuration of OpenStack images. As 
OpenStack is a very common system you can get a lot of prebuild images from
different linux distributions without having the requirement to build it on 
your own. However, those images are mostly configured to block root access by
ssh and use a user account which is the distributions name. This is a security
issue. Hence this role properly sets up the VM's SSH server, deltes the default
user (if known) and allows root access by ssh public key.

## Role Variables

All variables which can be overriden are stored in [defaults/main.yml](defaults/main.yml) file as well as in the table
below. Some Variables are generated during the run and are listed in the table below. These Variables are mainly
agnostic to LRZ related configurations.

| Name                              | Default Value | Description                   |
| --------------------------------- | ------------- | ----------------------------- |
| openstack_node_ssh_public_keys    | ~/ssh/*.pub   | Directory with public keys    |

## Playbook

```yaml
---
- hosts: all
  remote_user: debian
  become: true
  roles:
    - openstack-node
```

## Maintainer

- Alexander Goetz (2019 - )
