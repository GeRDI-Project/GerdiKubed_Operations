# Prometheus Monitoring System

This role deploys the prometheus monitoring system to the k8s cluster. The system is only monitoring metrics which are 
exportet by kublet for each node. Further instrumentations has to be adjusted by an individual config map. Documentation 
on prometheus configurations can be found at [http://prometheus.io](https://prometheus.io/docs/introduction/overview/).

## Editable Variables and Defaults

| Name                      | Default           | Description                                                                   |
| ------------------------- | ----------------- | ----------------------------------------------------------------------------- |
| PROMETHEUS_BASE_DIR       | /opt/prometheus   | Base directory with k8s configuration files                                   |
| PROMETHEUS_SERVER_VERSION | 2.9.1             | The version of the prometheus master server                                   |

## Usage Custom configMaps

## Reaching Prometheus Master Outside the Cluster

The prometheus server can be reached from outside the cluster. This allows to monitor multiple k8s clusters using a
single prometheus of grafana instance. The endpoint which is exposed by k8s is https://<lb-ip>/admin/prometheus. To
prevent unitended access, it is seccured by Basic Auth. The according username and password must be requested from the
cluster admin.

## Maintainer

- Alexander Goetz [LRZ] (2019 - )
