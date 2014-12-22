#!/bin/bash
RUNDIR="$( cd "$( dirname "${BASH_SOURCE[0]:-$$}" )" && pwd )"
PATH=${RUNDIR}/bin:${PATH}
# IP or Hostname of ESXI host
export ESXI_HOST=paladin

# ESXi Username
export ESXI_USERNAME=root

# ESXi Password
export ESXI_PASSWORD=funk9874

# Name of ESXi datastore to upload CoreOS VM
# This name must match your ESXi installation.  Configured datastores can be found using vSphere Client
#   under the setting View->Inventory->Summary->Resources->Datastore
export ESXI_DATASTORE=diskstation

# Name of vmware network.  The ESXi out-of-the-box default name is "VM Network".  If your ESXi installtion did
#   not change this name, leave this setting commented out. 
#   This name must match your ESXi installation.  Configured networks can be found using vSphere Client
#   under the setting View->Inventory->Summary->Resources->Network
#VM_NETWORK="xyz corp network"

# static hostname and IP address for our new single etcd server.  
# This must be a new unique address for your network.  This can be registered in DNS.
export ETCD_IP_ADDRESS=192.168.1.67
export ETCD_HOSTNAME=queenbee

# Network settings for our etcd server. Only the etcd server gets its network settings here.  The workers get this information from DHCP.
# Contact your network administrator for the correct settings to match your network
export GATEWAY=192.168.1.1
export DNS=192.168.1.42
export DOMAINS=example.com

# create and power on our etcd instance:
deploy_coreos_on_esxi2.sh    --channel alpha --core_os_hostname=${ETCD_HOSTNAME}  queenbee.user-data

# create and power on 3 worker instances:
deploy_coreos_on_esxi2.sh -s --channel alpha --core_os_hostname=workerbee1 worker-dhcp.user-data
deploy_coreos_on_esxi2.sh -s --channel alpha --core_os_hostname=workerbee2 worker-dhcp.user-data
deploy_coreos_on_esxi2.sh -s --channel alpha --core_os_hostname=workerbee3 worker-dhcp.user-data
