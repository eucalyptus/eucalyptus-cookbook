#### Install Info
default["eucalyptus"]["install-type"] = "package"
default["eucalyptus"]["release-rpm"] = "http://downloads.eucalyptus.com/software/eucalyptus/3.4/centos/6/x86_64/eucalyptus-release-3.4.noarch.rpm"
default["eucalyptus"]["euca2ools-rpm"] = "http://downloads.eucalyptus.com/software/euca2ools/3.0/centos/6/x86_64/euca2ools-release-3.0.noarch.rpm"
default["eucalyptus"]["epel-rpm"] = "http://downloads.eucalyptus.com/software/eucalyptus/3.4/centos/6/x86_64/epel-release-6.noarch.rpm"
default["eucalyptus"]["elrepo-rpm"] = "http://downloads.eucalyptus.com/software/eucalyptus/3.4/centos/6/x86_64/elrepo-release-6.noarch.rpm"
default['eucalyptus']['install-load-balancer'] = false

#### GLOBALS
default['eucalyptus']['admin-cred-dir'] = "/root"
default["eucalyptus"]["home-directory"] = "/"
default["eucalyptus"]["user"] = "eucalyptus"
default["eucalyptus"]["cloud-opts"] = ""
default["eucalyptus"]["install-load-balancer"] = true

## Networking Config
default["eucalyptus"]["network"]["mode"] = "MANAGED-NOVLAN"
default["eucalyptus"]["network"]["private-interface"] = "eth0"
default["eucalyptus"]["network"]["public-interface"] = "eth0"
default["eucalyptus"]["network"]["bridge-interface"] = "br0"
default["eucalyptus"]["network"]["subnet"] = "172.16.0.0"
default["eucalyptus"]["network"]["netmask"] = "255.255.0.0"
default["eucalyptus"]["network"]["addresses-per-net"] = "32"
default["eucalyptus"]["network"]["dns-server"] = "8.8.8.8"
default["eucalyptus"]["network"]["dhcp-daemon"] = "/usr/sbin/dhcpd41"

## Define Topology - Used for registration on CLC
default["eucalyptus"]["topology"]["clusters"]["default"]["cc-1"] = ""
default["eucalyptus"]["topology"]["clusters"]["default"]["sc-1"] = ""
default["eucalyptus"]["topology"]["clusters"]["default"]["nodes"] = ""
default["eucalyptus"]["topology"]["walrus"] = ""

default["eucalyptus"]["eutester"]["ssh"]["password"] = "foobar"

## Cluster the current recipe is running in more for
default["eucalyptus"]["cluster-name"] = "default"

## CC Specific
default["eucalyptus"]["cc"]["port"] = "8774"
default["eucalyptus"]["cc"]["scheduling-policy"] = "ROUNDROBIN"

## NC Specific
default["eucalyptus"]["nc"]["port"] = "8775"
default["eucalyptus"]["nc"]["service-path"] = "axis2/services/EucalyptusNC"
default["eucalyptus"]["nc"]["hypervisor"] = "kvm"
default["eucalyptus"]["nc"]["max-cores"] = "0"
default["eucalyptus"]["nc"]["instance-path"] = "/var/lib/eucalyptus/instances" 
