#
# Cookbook Name:: eucalyptus
# Recipe:: default
#Copyright [2014] [Eucalyptus Systems]
##
##Licensed under the Apache License, Version 2.0 (the "License");
##you may not use this file except in compliance with the License.
##You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
##    Unless required by applicable law or agreed to in writing, software
##    distributed under the License is distributed on an "AS IS" BASIS,
##    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##    See the License for the specific language governing permissions and
##    limitations under the License.
##

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

if node['eucalyptus']['admin-ssh-pub-key'] != ""
  execute "Add the admins ssh key to authorized keys" do
    command "echo #{node['eucalyptus']['admin-ssh-pub-key']} >> /root/.ssh/authorized_keys"
  end
end

execute "Flush and save iptables" do
  command "iptables -F; iptables -F -t nat; iptables-save > /etc/sysconfig/iptables"
end

## Setup NTP
include_recipe "ntp"
execute "ntpdate -u #{node["eucalyptus"]["ntp-server"]}" do
  cwd '/tmp'
end

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

if Eucalyptus::Enterprise.is_enterprise?(node)
  yum_repository "eucalyptus-enterprise-release" do
    description "Eucalyptus Enterprise Package Repo"
    url node["eucalyptus"]["enterprise-repo"]
    gpgkey "http://www.eucalyptus.com/sites/all/files/c1240596-eucalyptus-release-key.pub"
  end
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

execute 'yum install -y *epel*.rpm' do
  cwd '/tmp'
  not_if "ls /etc/yum.repos.d/epel*"
end

execute 'yum install -y *elrepo*.rpm' do
  cwd '/tmp'
  not_if "ls /etc/yum.repos.d/elrepo*"
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
    dejavu-serif-fonts device-mapper dhcp dhcp-common drbd drbd83 drbd83-kmod 
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

  configure_command = "export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && ./configure '--with-axis2=/usr/share/axis2-*' --with-axis2c=/usr/lib64/axis2c --prefix=$EUCALYPTUS --with-apache2-module-dir=/usr/lib64/httpd/modules --with-db-home=/usr/pgsql-9.1 --with-wsdl2c-sh=#{node["eucalyptus"]["home-directory"]}/euca-WSDL2C.sh"

  ### Run configure for open source
  execute "Run configure with open source bits"  do
    command configure_command
    cwd "#{node["eucalyptus"]["source-directory"]}"
    not_if "ls #{node["eucalyptus"]["source-directory"]}/vmware-broker"
  end
  ### Run configure with enterprise bits
  execute "Run configure with enterprise bits" do
    command configure_command + " --with-vddk=/opt/packages/vddk"
    cwd "#{node["eucalyptus"]["source-directory"]}"
    only_if "ls #{node["eucalyptus"]["source-directory"]}/vmware-broker"
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
