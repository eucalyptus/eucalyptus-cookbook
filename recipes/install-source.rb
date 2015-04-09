#
## Cookbook Name:: eucalyptus
## Recipe:: install-source
##
##Copyright [2014] [Eucalyptus Systems]
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
### Create eucalyptus user
user "eucalyptus" do
  supports :manage_home => true
  comment "Eucalyptus User"
  home "/home/eucalyptus"
  shell "/bin/bash"
end

### Used for monitoring in 4.1
group "eucalyptus-status"

source_directory = "#{node['eucalyptus']["home-directory"]}/source/#{node['eucalyptus']['source-branch']}"
home_directory =  node['eucalyptus']["home-directory"]

directory source_directory do
  recursive true
  owner "eucalyptus"
  group "eucalyptus"
end


### Add build deps repo
yum_repository "euca-build-deps" do
  description "Eucalyptus Build Dependencies repo"
  url node['eucalyptus']['build-deps-repo']
  action :add
  metadata_expire "1"
end

### This is a source install so we need the build time deps and runtime deps
### Build time first

%w{java-1.7.0-openjdk-devel ant ant-junit ant-nodeps apache-ivy axis2-adb axis2-adb-codegen axis2c-devel
  axis2-codegen curl-devel gawk git jpackage-utils libvirt-devel libxml2-devel json-c
  libxslt-devel m2crypto openssl-devel python-devel python-setuptools json-c-devel
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
  postgresql92 postgresql92-server python-boto python-devel python-setuptools
  rampartc rampartc-devel rsync scsi-target-utils sudo swig util-linux vconfig
  velocity vtun wget which xalan-j2-xsltc ipset ebtables librbd1 librados2}.each do |dependency|
  yum_package dependency do
    options node['eucalyptus']['yum-options']
    action :upgrade
  end
end

### Get WSDL2C
execute 'wget https://raw.github.com/eucalyptus/eucalyptus-rpmspec/master/euca-WSDL2C.sh && chmod +x euca-WSDL2C.sh' do
  cwd home_directory
end

execute "Remove source" do
  command "rm -rf #{source_directory}"
  only_if "#{node['eucalyptus']['rm-source-dir']}"
end

### Checkout Eucalyptus Source
git source_directory do
  repository node['eucalyptus']['source-repo']
  revision "refs/heads/#{node['eucalyptus']['source-branch']}"
  checkout_branch node['eucalyptus']['source-branch']
  enable_submodules true
  action :sync
end

yum_repository "euca-vmware-libs" do
  description "VDDK libs repo"
  url node['eucalyptus']['vddk-libs-repo']
  action :add
  only_if "ls #{source_directory}/vmware-broker"
  metadata_expire "1"
end

yum_package "vmware-vix-disklib" do
  only_if "ls #{source_directory}/vmware-broker"
  options node['eucalyptus']['yum-options']
  action :upgrade
end

configure_command = "export EUCALYPTUS='#{home_directory}' && ./configure '--with-axis2=/usr/share/axis2-*' --with-axis2c=/usr/lib64/axis2c --prefix=$EUCALYPTUS --with-apache2-module-dir=/usr/lib64/httpd/modules --with-db-home=/usr/pgsql-9.2 --with-wsdl2c-sh=#{home_directory}/euca-WSDL2C.sh"

### Run configure for open source
execute "Run configure with open source bits"  do
  command configure_command
  cwd source_directory
  not_if "ls #{source_directory}/vmware-broker"
end
### Run configure with enterprise bits
execute "Run configure with enterprise bits" do
  command configure_command + " --with-vddk=/opt/packages/vddk"
  cwd source_directory
  only_if "ls #{source_directory}/vmware-broker"
end

execute "echo \"export PATH=$PATH:#{home_directory}/usr/sbin/\" >>/root/.bashrc"

execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{home_directory}' && make && make install" do
  cwd source_directory
  timeout node["eucalyptus"]["compile-timeout"]
end

tools_dir = "#{source_directory}/tools"
if node['eucalyptus']['source-repo'].end_with?("internal")
  tools_dir = "#{source_directory}/eucalyptus/tools"
end

%w{eucalyptus-cloud eucalyptus-cc eucalyptus-nc}.each do |init_script|
  execute "ln -sf #{tools_dir}/eucalyptus-cloud /etc/init.d/#{init_script}" do
    creates "/etc/init.d/#{init_script}"
  end
  execute "chmod +x #{tools_dir}/eucalyptus-cloud"
end

if node["eucalyptus"]["network"]["mode"] == "EDGE"
  execute "ln -fs #{tools_dir}/eucanetd /etc/init.d/eucanetd"
  execute "chmod +x #{tools_dir}/eucanetd"
end

execute "Copy Policy Kit file for NC" do
  command "cp #{tools_dir}/eucalyptus-nc-libvirt.pkla /var/lib/polkit-1/localauthority/10-vendor.d/"
end

execute "#{home_directory}/usr/sbin/euca_conf --setup -d #{home_directory}"
