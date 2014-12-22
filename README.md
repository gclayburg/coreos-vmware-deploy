coreos-vmware-deploy
====================

Bash script for provisioning [CoreOS](https://coreos.com/) cluster on vmwware ESXi

This script will create a simple CoreOS cluster consisting of:
- one queenbee server that runs etcd with a static IP address
- 3 workerbee servers that use DHCP to get an IP address

# Why

This script is a simplified alternative to the [core os instructions for deploying onto vmware](https://coreos.com/docs/running-coreos/platforms/vmware/).
Installing CoreOS onto vmware using the CoreOS instructions is more complicated than other platforms like [vagrant](https://coreos.com/docs/running-coreos/platforms/vagrant/) since the vmware provider does not support the `$public_ipv4` and `$private_ipv4` variable substitutions in the [cloud-config user-data configuration file](https://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/).  

This project was created to work around these limitations and to automate the setup of a [single etcd CoreOS cluster](https://coreos.com/docs/cluster-management/setup/cluster-architectures/#easy-development/testing-cluster) on vmware ESXi.


# Installation

* Rename and edit `local.credentials.sample` to match your ESXi installation.  See script comments for details.

```
$ cp local.credentials.sample local.credentials
$ vi local.credentials
```

* Edit `create-cluster.sh` with your chosen IP address and run

```
$ vi create-cluster.sh
$ ./create-cluster.sh
```

You should now have a working 3 node CoreOS cluster.  You should be able to use [etcdctl](https://github.com/coreos/etcdctl#etcdctl), [fleetctl](https://coreos.com/docs/launching-containers/launching/fleet-using-the-client/), and [docker](https://www.docker.com/) commands on any node in the cluster, i.e.:

```
$ fleetctl list-machines
$ docker ps
$ etcdctl set /helloworld "I am workerbee2"
$ etcdctl get /helloworld
```

# Security

The supplied `*.user-data` files contain the specifics for the queenbee and workerbee roles.  They should work for you as-is, but if security is important to you, you'll want to modify these to put in your own credentials.  These templates will create a user named gclaybur with a few public keys and a default password of `opensesame1`.

# Updating 
The preferred method for changing the configuration of a coreos machine is to just create a new one with the new configuration and throw away the older ones.  Fleetd is pretty good at migrating workloads for you.  

However, if you'd rather modify an existing CoreOS server, this script can do that too.  For example, lets say you want to add your own ssh public key for the workerbee1 server.  You can do that with the `-u` option:

* Edit `worker-dhcp.user-data` and re-run the deploy script

```
$ vi worker-dhcp.user-data
$ . local.credentials
$ deploy_coreos_on_esxi2.sh -u --core_os_hostname=workerbee1 worker-dhcp.user-data
```

**Note:** CoreOS uses a mounted .iso image for reading the cloud-config data on VMware ESXi.  Make sure that the VM is powered off before running the script.  Otherwise, VMware will not recognize any changes.
**Note:** Be careful about formatting when editing the `*.user-data` files.  Leading spaces are significant.  See [CoreOS cloud-config documentation for details](https://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/)


# Inspiration

This script was inspired from this blog for deploying CoreOS onto vmware.

http://www.virtuallyghetto.com/2014/11/how-to-quickly-deploy-new-coreos-image-wvmware-tools-on-esxi.html

https://github.com/lamw/vghetto-scripts/blob/master/shell/deploy_coreos_on_esxi2.sh



