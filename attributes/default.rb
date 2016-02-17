#### Install Info
default["eucalyptus"]["install-type"] = "packages"
default["eucalyptus"]["source-repo"] = "https://github.com/eucalyptus/eucalyptus.git"
default["eucalyptus"]["source-branch"] = "master"
default['eucalyptus']['rm-source-dir'] = false
default["eucalyptus"]["eucalyptus-repo"] = "http://packages.release.eucalyptus-systems.com/yum/tags/eucalyptus-devel/rhel/$releasever/$basearch/"
default["eucalyptus"]["euca2ools-repo"] = "http://downloads.eucalyptus.com/software/euca2ools/3.3/centos/7/x86_64/"
default["eucalyptus"]["enterprise-repo"] = ""
default["eucalyptus"]["eucalyptus-gpg-key"] = "http://downloads.eucalyptus.com/software/gpg/eucalyptus-release-key.pub"
default["eucalyptus"]["euca2ools-gpg-key"] = "http://downloads.eucalyptus.com/software/gpg/eucalyptus-release-key.pub"
default['eucalyptus']['enterprise']['clientcert'] = "insertclientcerthere"
default['eucalyptus']['enterprise']['clientkey'] = "insertclientkeyhere"
default['eucalyptus']['enterprise']['sslverify'] = true
default['eucalyptus']['install-service-image'] = true
#default['eucalyptus']['imaging-vm-type'] = 'm1.small'
#default['eucalyptus']['loadbalancing-vm-type'] = 'm1.small'
default['eucalyptus']['service-image-repo'] = ""
default["eucalyptus"]["build-deps-repo"] = "http://packages.release.eucalyptus-systems.com/yum/tags/eucalyptus-devel/rhel/$releasever/$basearch/"
default['eucalyptus']['vddk-libs-repo'] = "http://packages.release.eucalyptus-systems.com/yum/tags/enterprise-devel/centos/$releasever/$basearch/"
default["eucalyptus"]["epel-rpm"] = "http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
default['eucalyptus']['eustore-url'] = "http://emis.eucalyptus.com/"
default['eucalyptus']['default-img-url'] = "http://euca-vagrant.s3.amazonaws.com/cirrosraw.img"
default['eucalyptus']['yum-options'] = ""
default['eucalyptus']['init-script-url'] = ""
default['eucalyptus']['post-script-url'] = ""
default['eucalyptus']['cloud-libs-branch'] = "master"

#### User console
default['eucalyptus']['user-console']['source-branch'] = "develop"
default['eucalyptus']['user-console']['source-repo'] = "https://github.com/eucalyptus/eucaconsole"
default['eucalyptus']['user-console']['install-type'] = "packages"
default['eucalyptus']['user-console']['packaging-repo'] = "https://github.com/eucalyptus/eucaconsole-rpmspec"
default['eucalyptus']['user-console']['packaging-branch'] = "develop"

#### GLOBALS
default['eucalyptus']['admin-cred-dir'] = "/root"
default['eucalyptus']['admin-ssh-pub-key'] = ""
default["eucalyptus"]["home-directory"] = "/"
default["eucalyptus"]["set-bind-addr"] = false
# default["eucalyptus"]["bind-interface"] = 'eth0'
default["eucalyptus"]["log-level"] = "INFO"
default["eucalyptus"]["user"] = "eucalyptus"
default["eucalyptus"]["cloud-opts"] = ""
### Topology must be set for key sync to work
default['eucalyptus']['sync-keys'] = true
default["eucalyptus"]["local-cluster-name"] = "default"
default["eucalyptus"]["default-image"] = "cirros"
default["eucalyptus"]["cloud-keys"] = {}
default["eucalyptus"]["ntp-server"] = "pool.ntp.org"
default["eucalyptus"]["compile-timeout"] = 7200
default["eucalyptus"]["network"]["metadata-use-private-ip"] = "N"
default["eucalyptus"]["network"]["metadata-ip"] = ""
default["eucalyptus"]["network"]["nc-router"] = ""
default["eucalyptus"]["network"]["mode"] = "MANAGED-NOVLAN"

### System properties
### this will be ingressed at configure time
default["eucalyptus"]["system-properties"] = {}

## Networking Config for EDGE
default["eucalyptus"]["network"]['config-json'] = {}
## Networking config for managed modes
default["eucalyptus"]["network"]["private-interface"] = "eth0"
default["eucalyptus"]["network"]["public-interface"] = "eth0"
default["eucalyptus"]["network"]["bridge-interface"] = "br0"
default["eucalyptus"]["network"]["bridged-nic"] = "eth0"
default["eucalyptus"]["network"]["bridge-ip"] = ""
default["eucalyptus"]["network"]["bridge-netmask"] = ""
default["eucalyptus"]["network"]["bridge-gateway"] = ""
default["eucalyptus"]["network"]["public-ips"] = ""
default["eucalyptus"]["network"]["subnet"] = "172.16.0.0"
default["eucalyptus"]["network"]["netmask"] = "255.255.0.0"
default["eucalyptus"]["network"]["broadcast"] = "172.16.255.255"
default["eucalyptus"]["network"]["addresses-per-net"] = "32"
default["eucalyptus"]["network"]["dns-server"] = "8.8.8.8"
default["eucalyptus"]["network"]["dhcp-daemon"] = "/usr/sbin/dhcpd"
default["eucalyptus"]["network"]["disable-tunneling"] = "Y"

## Define Topology - Used for registration on CLC
#default["eucalyptus"]["topology"]["clc-1"] = ""
#default["eucalyptus"]["topology"]["clusters"] = {}
##############################################################################
### Clusters are defined with the following parameters in an environment file
##############################################################################
#default["eucalyptus"]["topology"]["clusters"]["default"]["cc-1"] = ""
#default["eucalyptus"]["topology"]["clusters"]["default"]["sc-1"] = ""
#default["eucalyptus"]["topology"]["clusters"]["default"]["nodes"] = ""
#default["eucalyptus"]["topology"]["clusters"]["default"]["storage-backend"] = "overlay"
#default["eucalyptus"]["topology"]["clusters"]["default"]["hypervisor"] = "kvm"
#default["eucalyptus"]["topology"]["clusters"]["default"]["das-device"] = "vg01"
#default["eucalyptus"]["topology"]["walrus"] = ""
#default["eucalyptus"]["topology"]["user-facing"] = []
#default['eucalyptus']['topology']['riakcs']['endpoint'] = ""
#default['eucalyptus']['topology']['riakcs']['access-key'] = ""
#default['eucalyptus']['topology']['riakcs']['secret-key'] = ""


## CC Specific
default["eucalyptus"]["cc"]["port"] = "8774"
default["eucalyptus"]["cc"]["scheduling-policy"] = "ROUNDROBIN"

## Storage
default["eucalyptus"]["storage"]["emc"]["navicli-url"] = "http://mirror.eucalyptus-systems.com/mirrors/emc/NaviCLI-Linux-64-latest.rpm"
default["eucalyptus"]["storage"]["emc"]["navicli-path"] = "/opt/Navisphere/bin/naviseccli"
default["eucalyptus"]["storage"]["emc"]["storagepool"] = "0"

## NC Specific
default["eucalyptus"]["nc"]["install-qemu-migration"] = true
default["eucalyptus"]["nc"]["port"] = "8775"
#default["eucalyptus"]["nc"]["work-size"] = "0"
#default["eucalyptus"]["nc"]["cache-size"] = "0"
default["eucalyptus"]["nc"]["service-path"] = "axis2/services/EucalyptusNC"
default["eucalyptus"]["nc"]["hypervisor"] = "kvm"
default["eucalyptus"]["nc"]["max-cores"] = "0"
default["eucalyptus"]["nc"]["instance-path"] = "/var/lib/eucalyptus/instances"
default["eucalyptus"]["nc"]["ipset-maxsets"] = "2048"
