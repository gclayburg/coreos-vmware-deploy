coreos-vmware-deploy
====================

Bash script for provisioning [CoreOS](https://coreos.com/) cluster on vmwware ESXi

This script will create a simple CoreOS cluster consisting of:
- one server that runs etcd with a static IP address
- 3 worker servers that use DHCP to get an IP address

# Why

This script is an simplified alternative to the [core os instructions for deploying onto vmware](https://coreos.com/docs/running-coreos/platforms/vmware/).
Installing CoreOS onto vmware using the CoreOS instructions is more complicated than other platforms like [vagrant](https://coreos.com/docs/running-coreos/platforms/vagrant/) since the vmware provider does not support the `$public_ipv4` and `$private_ipv4` variable substitutions in the [cloud-config user-data configuration file](https://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/).

This project was created to work around these limitations and to automate the setup of a [single etcd CoreOS cluster](https://coreos.com/docs/cluster-management/setup/cluster-architectures/#easy-development/testing-cluster) on vmware ESXi.


# Installation


* Rename and edit [local.credentials.sample](https://github.com/gclayburg/coreos-vmware-deploy/blob/master/local.credentials.sample) to match your ESXi installation.  See script comments for details.

```
$ cp local.credentials.sample local.credentials
$ vi local.credentials
```

* Edit create-cluster.sh with your chosen IP address

```
$ vi create-cluster.sh
```

* run script:

```
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

The supplied .user-data files contain the specifics for the queenbee and workerbee roles.  They should work for you as-is, but you probably want to modify these to put in your own credentials.  These templates will create a user named gclaybur with a few public keys.


# Inspiration

This script was inspired from this blog for deploying CoreOS onto vmware.

http://www.virtuallyghetto.com/2014/11/how-to-quickly-deploy-new-coreos-image-wvmware-tools-on-esxi.html

https://github.com/lamw/vghetto-scripts/blob/master/shell/deploy_coreos_on_esxi2.sh



