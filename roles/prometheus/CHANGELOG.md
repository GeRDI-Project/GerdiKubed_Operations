# Changelog

This changelog tracks all changes which were made to the prometheus role and its related content.

## [0.0.1] - 2019-04-25
### Added
- Ansible tasks for deploying a prometheus server on k8s, using official container images
- k8s manifests for deployment, service and persitent volume claim
- k8s manifest to create the kube-monitor namespace if not already present
