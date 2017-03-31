#### Install Info
default["eucalyptus"]["install-type"] = "packages"

default["eucalyptus"]["source-repo"] = "https://github.com/eucalyptus/eucalyptus.git"
default["eucalyptus"]["source-branch"] = "master"
default["eucalyptus"]["cloud-libs-repo"] = "https://github.com/eucalyptus/eucalyptus-cloud-libs.git"
default["eucalyptus"]["cloud-libs-branch"] = "master"

default["eucalyptus"]["san-repo"] = ""
default["eucalyptus"]["san-branch"] = "master"
default["eucalyptus"]["san-libs-repo"] = ""
default["eucalyptus"]["san-libs-branch"] = "master"

default["eucalyptus"]["selinux-repo"] = "https://github.com/eucalyptus/eucalyptus-selinux"
default["eucalyptus"]["selinux-branch"] = "master"

default['eucalyptus']['rm-source-dir'] = false
default["eucalyptus"]["eucalyptus-repo"] = "http://downloads.eucalyptus.com/software/eucalyptus/nightly/devel/rhel/$releasever/$basearch/"
default["eucalyptus"]["euca2ools-repo"] = "http://downloads.eucalyptus.com/software/euca2ools/nightly/devel/rhel/$releasever/$basearch/"
default["eucalyptus"]["enterprise-repo"] = ""
default["eucalyptus"]["eucalyptus-gpg-key"] = "http://downloads.eucalyptus.com/software/gpg/eucalyptus-release-key.pub"
default["eucalyptus"]["euca2ools-gpg-key"] = "http://downloads.eucalyptus.com/software/gpg/eucalyptus-release-key.pub"
default['eucalyptus']['clientcert'] = "insertclientcerthere"
default['eucalyptus']['clientkey'] = "insertclientkeyhere"
default['eucalyptus']['enterprise']['sslverify'] = true
default['eucalyptus']['install-service-image'] = true
#default['eucalyptus']['imaging-vm-type'] = 'm1.small'
#default['eucalyptus']['loadbalancing-vm-type'] = 'm1.small'
default['eucalyptus']['service-image-repo'] = ""
default["eucalyptus"]["epel-rpm"] = "http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
default['eucalyptus']['eustore-url'] = "http://emis.eucalyptus.com/"
default['eucalyptus']['default-img-url'] = "http://euca-vagrant.s3.amazonaws.com/cirrosraw.img"
default['eucalyptus']['yum-options'] = ""
default['eucalyptus']['init-script-url'] = ""
default['eucalyptus']['post-script-url'] = ""
default['eucalyptus']['configure-service-timeout'] = 180

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
# Allow the cookbooks discover the Eucalyptus service address to bind to. Requires bind-interface or bind-network to be set
default["eucalyptus"]["set-bind-addr"] = false
# If using 'set-bind-addr', 'bind-network' is used to locate the host address to bind to
default["eucalyptus"]["bind-network"] = ""
# If using 'set-bind-addr', 'bind-interface' is used to locate the host address to bind to
# default["eucalyptus"]["bind-interface"] = 'eth0'
default["eucalyptus"]["log-level"] = "INFO"
default["eucalyptus"]["user"] = "eucalyptus"
default["eucalyptus"]["cloud-opts"] = ""
default['eucalyptus']['dns-domain'] = nil
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
default["eucalyptus"]["cc"]["max-instances-per-cc"] = "128"

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

# Ceph Packages
default['eucalyptus']['ceph-repo'] = "http://download.ceph.com/rpm-hammer/el7/x86_64/"

# ceph-rgw
default['eucalyptus']['topology']['objectstorage']['access-key'] = nil
default['eucalyptus']['topology']['objectstorage']['secret-key'] = nil
default['eucalyptus']['topology']['objectstorage']['ceph-radosgw'] = nil

# midokura repository
default['eucalyptus']['midonet']['repository'] = "opensource"
default['eucalyptus']['midonet']['version'] = 5.2

# open-source midonet
default['eucalyptus']['midonet']['midonet-url'] = "http://builds.midonet.org/midonet-VERSION/stable/el7/"
default['eucalyptus']['midonet']['misc-url'] = "http://builds.midonet.org/misc/stable/el7/"
default['eucalyptus']['midonet']['gpgkey'] = "https://builds.midonet.org/midorepo.key"

# midokura enterprise midonet
default['eucalyptus']['midonet']['mem-urn'] = "repo.midokura.com/mem-VERSION/stable/el7/"
default['eucalyptus']['midonet']['mem-misc-url'] = "http://repo.midokura.com/misc/stable/el7/"
default['eucalyptus']['midonet']['mem-gpgkey'] = "https://repo.midokura.com/midorepo.key"
default['eucalyptus']['midonet']['repo-username'] = "midokura-username"
default['eucalyptus']['midonet']['repo-password'] = "midokura-password"
default['eucalyptus']['midonet']['zookeeper-port'] = 2181

# midonet-cluster
default['eucalyptus']['midonet']['http-port'] = 8080
default['eucalyptus']['midonet']['http-host'] = "127.0.0.1"
default['eucalyptus']['midonet']['max-heap-size'] = nil
default['eucalyptus']['midonet']['heap-newsize'] = nil

default['eucalyptus']['midonet']['initial-tenant'] = "mido_tenant"
default['eucalyptus']['midonet']['default-tunnel-zone'] = "mido-tz"

# midolman
default['eucalyptus']['midolman']['max-heap-size'] = nil
