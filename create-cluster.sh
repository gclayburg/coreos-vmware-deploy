#!/bin/bash
RUNDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$$}" )" && pwd )"
PATH=${RUNDIR}/bin:${PATH}
if [[ -f ${RUNDIR}/local.credentials ]]; then
  . ${RUNDIR}/local.credentials
else
  echo "Error: Please create local.credentials file from local.credentials.sample for your local network settings and credentials"
  exit 1
fi
# static hostname and IP address for our new single etcd server.
# This must be a new unique address for your network.  This can be registered in DNS.
export ETCD_IP_ADDRESS=192.168.1.69
export ETCD_HOSTNAME=queenbee69

# create and power on our etcd instance:
deploy_coreos_on_esxi2.sh  -s  --channel alpha --core_os_hostname=${ETCD_HOSTNAME}  queenbee.user-data

# create and power on 3 worker instances:
deploy_coreos_on_esxi2.sh -s --channel alpha --core_os_hostname=workerbee1 worker-dhcp.user-data
deploy_coreos_on_esxi2.sh -s --channel alpha --core_os_hostname=workerbee2 worker-dhcp.user-data
deploy_coreos_on_esxi2.sh -s --channel alpha --core_os_hostname=workerbee3 worker-dhcp.user-data
