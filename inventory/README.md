# Configuring the Ansible Inventory and Playbook to Deploy a Kubernetes Cluster

This folder contains template files (.tmpl) for an ansible inventory (hosts.ini.tmpl) as well as variables files which
allow to configure the kubernetes setup according to the user's requirements. The variable file (main.yml) list all
possible configuration options and shows the according default variables if defined. Varibales that have default
configurations are commented out. However, to change the default configuration just remove the hashtag in front and 
change the value.

## Usage

As mentioned in the introduction, the whole playbook has default configuration variables, which allow the user to make
an initital deployment as long as the inventory is complete. However, this might fail in many cases due to specific
configurational requirements. The default variables which can be set by the user are shown at group_vars/all/main.yml.
Variables are mainy commented out as the default values, which are shown with the outcommented variables, are used.
To change a certain variable just remove the hashtag in front of it and change the value:

```yaml
# Variable with default entry.
# K8S_VERSION:                "v1.14.1"

# Modified value of the variable
K8S_VERSION:                "v1.15.0"
```

## Securing Variables Containing Sensitive Information

Passwords and credentials should not be stored in plain text in the variable files. Instead, it is advisable to store
them encrypted in an ansible vault. To do so, just add the vault_file to the according group_vars folder and reference
the variable, which is stored in the vault, to the according variable in the configuration file.

In the following example, the variable GRAFANA_ADMIN_UNAME just references to an encrypted variable in an ansible vault
that is stored at group_vars/all/secrets.yml. To setup the vault use the ansible-vault commands:

```bash
ansible-vault create group_vars/all/secrets.yml
```

In the secrets.yml we store the password in the variables SECRETS_GRAFANA_ADMIN_UNAME

```yaml
SECRETS_GRAFANA_ADMIN_UNAME: superadmin
```

In order to use the default varibale, we just reference the secrets variable in the main.yml file at group_vars/all

```yaml
# Default entry in the main.yml file
# GRAFANA_ADMIN_UNAME: grafana

# Usage of encrypted variable for grafana admin username
GRAFANA_ADMIN_UNAME: "{{ SECRETS_GRAFANA_ADMIN_UNAME }}"
```

For further documentation on ansible vaults please see <https://docs.ansible.com/ansible/latest/user_guide/vault.html>

## Maintainer

- Alexander Götz (2019-)

## Copyright

- Leibniz Supercomputing Centre (2019-)
