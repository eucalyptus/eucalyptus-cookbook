#### Install Info
default["eucalyptus"]["install-type"] = "packages"
default["eucalyptus"]["source-repo"] = "https://github.com/eucalyptus/eucalyptus.git"
default["eucalyptus"]["source-branch"] = "testing"
default["eucalyptus"]["eucalyptus-repo"] = "http://downloads.eucalyptus.com/software/eucalyptus/3.4/centos/6/x86_64/"
default["eucalyptus"]["euca2ools-repo"] = "http://downloads.eucalyptus.com/software/euca2ools/3.0/centos/6/x86_64/"
default['eucalyptus']['load-balancer-repo'] = ""
default["eucalyptus"]["build-deps-repo"] = "http://downloads.eucalyptus.com/software/eucalyptus/build-deps/3.3/centos/6/x86_64/"
default['eucalyptus']['vddk-libs-repo'] = "http://packages.release.eucalyptus-systems.com/yum/tags/euca-master-plugin-build-bootstrap/centos/$releasever/$basearch/"
default["eucalyptus"]["epel-rpm"] = "http://downloads.eucalyptus.com/software/eucalyptus/3.4/centos/6/x86_64/epel-release-6.noarch.rpm"
default["eucalyptus"]["elrepo-rpm"] = "http://downloads.eucalyptus.com/software/eucalyptus/3.4/centos/6/x86_64/elrepo-release-6.noarch.rpm"
default['eucalyptus']['install-load-balancer'] = false
default['eucalyptus']['yum-options'] = ""
default['eucalyptus']['init-script-url'] = ""

#### GLOBALS
default['eucalyptus']['admin-cred-dir'] = "/root"
default["eucalyptus"]["home-directory"] = "/"
default["eucalyptus"]["source-directory"] = "/"
default["eucalyptus"]["user"] = "eucalyptus"
default["eucalyptus"]["cloud-opts"] = ""
default["eucalyptus"]["install-load-balancer"] = true
default["eucalyptus"]["local-cluster-name"] = "default"
default["eucalyptus"]["default-image"] = "cirros"

## Networking Config
default["eucalyptus"]["network"]["mode"] = "MANAGED-NOVLAN"
default["eucalyptus"]["network"]["private-interface"] = "eth0"
default["eucalyptus"]["network"]["public-interface"] = "eth0"
default["eucalyptus"]["network"]["bridge-interface"] = "br0"
default["eucalyptus"]["network"]["bridged-nic"] = "eth0"
default["eucalyptus"]["network"]["public-ips"] = ""
default["eucalyptus"]["network"]["private-ips"] = "172.16.0.1-172.16.0.100"
default["eucalyptus"]["network"]["subnet"] = "172.16.0.0"
default["eucalyptus"]["network"]["netmask"] = "255.255.0.0"
default["eucalyptus"]["network"]["addresses-per-net"] = "32"
default["eucalyptus"]["network"]["dns-server"] = "8.8.8.8"
default["eucalyptus"]["network"]["dhcp-daemon"] = "/usr/sbin/dhcpd41"

## Define Topology - Used for registration on CLC
default["eucalyptus"]["topology"]["clusters"]["default"]["cc-1"] = ""
default["eucalyptus"]["topology"]["clusters"]["default"]["sc-1"] = ""
default["eucalyptus"]["topology"]["clusters"]["default"]["nodes"] = ""
default["eucalyptus"]["topology"]["clusters"]["default"]["storage-backend"] = "overlay"
default["eucalyptus"]["topology"]["walrus"] = ""
default["eucalyptus"]["topology"]["osg"] = ""
default['eucalyptus']['topology']['riak']['endpoint'] = ""
default['eucalyptus']['topology']['riak']['access-key'] = ""
default['eucalyptus']['topology']['riak']['secret-key'] = ""


## CC Specific
default["eucalyptus"]["cc"]["port"] = "8774"
default["eucalyptus"]["cc"]["scheduling-policy"] = "ROUNDROBIN"

## NC Specific
default["eucalyptus"]["nc"]["port"] = "8775"
default["eucalyptus"]["nc"]["work-size"] = "0"
default["eucalyptus"]["nc"]["cache-size"] = "0"
default["eucalyptus"]["nc"]["service-path"] = "axis2/services/EucalyptusNC"
default["eucalyptus"]["nc"]["hypervisor"] = "kvm"
default["eucalyptus"]["nc"]["max-cores"] = "0"
default["eucalyptus"]["nc"]["instance-path"] = "/var/lib/eucalyptus/instances" 
