#!/bin/sh


CEPHADM=$(which cephadm)

if [[ "${CEPHADM}X" == "X" ]]
then
	echo "cephadm not installed!"
	exit 0
fi

# RHEL Default container images ------------------------------------------------
RHEL_DEFAULT_IMAGE='registry.redhat.io/rhceph-beta/rhceph-5-rhel8:latest'
RHEL_DEFAULT_IMAGE_IS_MASTER='False'
RHEL_DEFAULT_IMAGE_RELEASE='pacific'
RHEL_DEFAULT_PROMETHEUS_IMAGE="registry.redhat.io/openshift4/ose-prometheus:v4.6"
RHEL_DEFAULT_NODE_EXPORTER_IMAGE="registry.redhat.io/openshift4/ose-prometheus-node-exporter:v4.5"
RHEL_DEFAULT_GRAFANA_IMAGE="registry.redhat.io/rhceph-beta/rhceph-5-dashboard-rhel8:latest"
RHEL_DEFAULT_ALERT_MANAGER_IMAGE="registry.redhat.io/openshift4/ose-prometheus-alertmanager:v4.5"
# ------------------------------------------------------------------------------
# LYVE Default container images ------------------------------------------------
LYVE_DEFAULT_IMAGE='cadmin:5000/rhceph-beta/rhceph-5-rhel8'
LYVE_DEFAULT_IMAGE_IS_MASTER='False'
LYVE_DEFAULT_IMAGE_RELEASE='pacific'
LYVE_DEFAULT_PROMETHEUS_IMAGE='cadmin:5000/openshift4/ose-prometheus:v4.6'
LYVE_DEFAULT_NODE_EXPORTER_IMAGE="cadmin:5000/openshift4/ose-prometheus-node-exporter:v4.5"
LYVE_DEFAULT_GRAFANA_IMAGE="cadmin:5000/rhceph-beta/rhceph-5-dashboard-rhel8:latest"
LYVE_DEFAULT_ALERT_MANAGER_IMAGE="cadmin:5000/openshift4/ose-prometheus-alertmanager:v4.5"
# ------------------------------------------------------------------------------

sed -i  's!^DEFAULT_IMAGE =.*!DEFAULT_IMAGE = "'${LYVE_DEFAULT_IMAGE}'"!g' ${CEPHADM}
sed -i  's!^DEFAULT_PROMETHEUS_IMAGE =.*!DEFAULT_PROMETHEUS_IMAGE = "'${LYVE_DEFAULT_PROMETHEUS_IMAGE}'"!g' ${CEPHADM}
sed -i  's!^DEFAULT_NODE_EXPORTER_IMAGE =.*!DEFAULT_NODE_EXPORTER_IMAGE = "'${LYVE_DEFAULT_NODE_EXPORTER_IMAGE}'"!g' ${CEPHADM}
sed -i  's!^DEFAULT_GRAFANA_IMAGE =.*!DEFAULT_GRAFANA_IMAGE = "'${LYVE_DEFAULT_GRAFANA_IMAGE}'"!g' ${CEPHADM}
sed -i  's!^DEFAULT_ALERT_MANAGER_IMAGE =.*!DEFAULT_ALERT_MANAGER_IMAGE = "'${LYVE_DEFAULT_ALERT_MANAGER_IMAGE}'"!g' ${CEPHADM}
