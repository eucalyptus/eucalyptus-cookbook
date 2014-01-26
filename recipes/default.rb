#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
## Create home directory
if node["eucalyptus"]["home-directory"] != "/"
  directory node["eucalyptus"]["home-directory"] do
    owner "eucalyptus"
    group "eucalyptus"
    mode 00750
    action :create
  end
end

## Init script
if node['eucalyptus']['init-script-url'] != ""
  remote_file "#{node['eucalyptus']['home-directory']}/init.sh" do
    source node['eucalyptus']['init-script-url']
    mode "777"
  end
  execute 'Running init script' do
    command "bash #{node['eucalyptus']['home-directory']}/init.sh"
  end
end

## Setup NTP
include_recipe "ntp"

## Disable SELinux
selinux_state "SELinux Disabled" do
  action :disabled
end

## Install repo rpms
yum_repository "eucalyptus-release" do
  description "Eucalyptus Package Repo"
  url node["eucalyptus"]["eucalyptus-repo"]
  gpgkey "http://www.eucalyptus.com/sites/all/files/c1240596-eucalyptus-release-key.pub"
end

yum_repository "euca2ools-release" do
  description "Euca2ools Package Repo"
  url node["eucalyptus"]["euca2ools-repo"]
  gpgkey "http://www.eucalyptus.com/sites/all/files/c1240596-eucalyptus-release-key.pub"
end

remote_file "/tmp/epel-release.rpm" do
  source node["eucalyptus"]["epel-rpm"]
  not_if "rpm -qa | grep 'epel-release'"
end

remote_file "/tmp/elrepo-release.rpm" do
  source node["eucalyptus"]["elrepo-rpm"]
  not_if "rpm -qa | grep 'elrepo-release'"
end

execute 'yum install -y *release*.rpm' do
  cwd '/tmp'
  only_if "ls /tmp/*release*.rpm"
end

if node["eucalyptus"]["install-type"] == "source"
  ### Create eucalyptus user
  user "eucalyptus" do
    supports :manage_home => true
    comment "Eucalyptus User"
    home "/home/eucalyptus"
    shell "/bin/bash"
  end

  ### Add build deps repo
  yum_repository "euca-build-deps" do
    description "Eucalyptus Build Dependencies repo"
    url node['eucalyptus']['build-deps-repo']
    action :add
  end

  ### This is a source install so we need the build time deps and runtime deps
  ### Build time first
  
  %w{java-1.7.0-openjdk-devel ant ant-nodeps apache-ivy axis2-adb axis2-adb-codegen axis2c-devel
    axis2-codegen curl-devel gawk git jpackage-utils libvirt-devel libxml2-devel 
    libxslt-devel m2crypto openssl-devel python-devel python-setuptools
    rampartc-devel swig xalan-j2-xsltc}.each do |dependency|
    yum_package dependency do
      options node['eucalyptus']['yum-options']
      action :upgrade
    end
  end

  ### Runtime deps
  %w{java-1.7.0-openjdk gcc bc make ant ant-nodeps apache-ivy axis2-adb-codegen axis2-codegen axis2c 
    axis2c-devel bridge-utils coreutils curl curl-devel scsi-target-utils 
    dejavu-serif-fonts device-mapper dhcp41 dhcp41-common drbd drbd83 drbd83-kmod 
    drbd83-utils e2fsprogs euca2ools file gawk httpd iptables iscsi-initiator-utils jpackage-utils kvm 
    PyGreSQL libcurl libvirt libvirt-devel libxml2-devel libxslt-devel lvm2 m2crypto
    openssl-devel parted patch perl-Crypt-OpenSSL-RSA perl-Crypt-OpenSSL-Random 
    postgresql91 postgresql91-server python-boto python-devel python-setuptools 
    rampartc rampartc-devel rsync scsi-target-utils sudo swig util-linux vconfig 
    velocity vtun wget which xalan-j2-xsltc ipset ebtables}.each do |dependency|
    yum_package dependency do
      options node['eucalyptus']['yum-options']
      action :upgrade
    end
  end
  
  ### Get WSDL2C
  execute 'wget https://raw.github.com/eucalyptus/eucalyptus-rpmspec/master/euca-WSDL2C.sh && chmod +x euca-WSDL2C.sh' do
    cwd node["eucalyptus"]["home-directory"]
  end

  ### Checkout Eucalyptus Source
  execute "Checkout source" do
    command "git clone #{node['eucalyptus']['source-repo']} -b #{node['eucalyptus']['source-branch']} #{node['eucalyptus']['source-directory']}"
  end

  execute "Init submodules" do
    cwd "#{node["eucalyptus"]["source-directory"]}"
    command "git submodule init && git submodule update"
  end

  yum_repository "euca-vmware-libs" do
    description "VDDK libs repo"
    url node['eucalyptus']['vddk-libs-repo']
    action :add
    only_if "ls #{node["eucalyptus"]["source-directory"]}/vmware-broker"
  end

  yum_package "vmware-vix-disklib" do
    only_if "ls #{node["eucalyptus"]["source-directory"]}/vmware-broker"  
    options node['eucalyptus']['yum-options']
    action :upgrade
  end

  configure_command = "export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && ./configure '--with-axis2=/usr/share/axis2-*' --with-axis2c=/usr/lib64/axis2c --prefix=$EUCALYPTUS --with-apache2-module-dir=/usr/lib64/httpd/modules --with-db-home=/usr/pgsql-9.1 --with-wsdl2c-sh=#{node["eucalyptus"]["home-directory"]}/euca-WSDL2C.sh --with-vddk=/opt/packages/vddk"

  ### Run configure
  execute configure_command do
    cwd "#{node["eucalyptus"]["source-directory"]}"
  end
end

execute "ssh-keygen -f /root/.ssh/id_rsa -P ''" do
  not_if "ls /root/.ssh/id_rsa"
end

execute 'Authorize passwordless SSH for self' do
  command "cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && chmod og-r /root/.ssh/authorized_keys"
end

execute 'Add host key' do
  command "ssh-keyscan #{node['ipaddress']} >> /root/.ssh/known_hosts"
end
