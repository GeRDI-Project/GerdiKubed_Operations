# Version Configuration (group_vars/all.tmpl)
* DOCKER_VERSION:
  - Set version of Docker Container Engine (Community Edition) installation
  - Consult https://docs.docker.com/engine/release-notes/ for a list of versions
  - Example value: 5:18.09.1~3-0~debian-stretch
* GOLANG_VERSION:
  - Set version of Go Programming Language to be installed
  - Consult https://golang.org/doc/devel/release.html for a list of versions
  - Example value: go1.11.1
* K8S_VERSION:
  - Set version of Kubernetes Container Orchestration Engine installation
  - Consult: https://github.com/kubernetes/kubernetes/releases for a list of versions
  - Example value: v1.11.7
* OPENVSWITCH_VERSION:
  - Set version of Open vSwitch Multilayer Virtual Switch installation
  - Consult: https://packages.debian.org/de/stretch/openvswitch-switch for the latest version
  - Example value: 2.6.2~pre+git20161223-3
* OVN_HOST_VERSION / OVN_CENTRAL_VERSION:
  - Set version of ovn-host (node) and / or ovn-central (master), both default to OPENVSWITCH_VERSION
    if not specifically replaced
  - Consult: https://packages.debian.org/en/stretch/ovn-host and https://packages.debian.org/en/stretch/ovn-central
    for the latest versions
  - Example value: 2.6.2~pre+git20161223-3
* CNI_VERSION:
  - Set version of Container Network Interface (CNI) binaries to install
  - Consult https://github.com/containernetworking/cni/releases/ for the latest release version
  - Example value: v0.5.2
