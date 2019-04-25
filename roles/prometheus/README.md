# Prometheus Monitoring System

This role deploys the prometheus monitoring system to the k8s cluster. 

## Editable Variables and Defaults

| Name                      | Default           | Description                                                                   |
| ------------------------- | ----------------- | ----------------------------------------------------------------------------- |
| PROMETHEUS_BASE_DIR       | /opt/prometheus   | Base directory with k8s configuration files                                   |
| PROMETHEUS_SERVER_VERSION | 2.9.1             | The version of the prometheus master server                                   |
