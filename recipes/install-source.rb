#
## Cookbook Name:: eucalyptus
## Recipe:: install-source
##
## © Copyright 2014-2016 Hewlett Packard Enterprise Development Company LP
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

# used for platform_version comparison
require 'chef/version_constraint'

execute 'remove kvm_intel module if loaded' do
  command 'modprobe -r kvm_intel'
  only_if { '/sbin/lsmod | grep kvm_intel' }
end

execute 'remove kvm module if loaded' do
  command 'modprobe -r kvm'
  only_if { '/sbin/lsmod | grep kvm' }
end

### Used for monitoring in 4.1
group "eucalyptus-status"

### Create eucalyptus user
user "eucalyptus" do
  supports :manage_home => true
  comment "Eucalyptus cloud"
  home "/var/lib/eucalyptus"
  system true
  shell "/sbin/nologin"
end

home_directory =  node['eucalyptus']["home-directory"]

yum_repository "eucalyptus" do
  description "Eucalyptus repo"
  url node['eucalyptus']['eucalyptus-repo']
  action :add
  metadata_expire "1"
  gpgcheck false
end


### This is a source install so we need the build time deps and runtime deps
### Build time first

el7build = %w{java-1.8.0-openjdk-devel ant ant-junit apache-ivy
    axis2c-devel axis2 curl-devel gawk git jpackage-utils libvirt-devel
    libxml2-devel json-c libxslt-devel m2crypto openssl-devel python-devel
    python-setuptools json-c-devel rampartc-devel swig xalan-j2-xsltc
    gengetopt selinux-policy-devel autoconf}

el7runtime = %w{java-1.8.0-openjdk gcc bc make ant apache-ivy axis2c axis2
    axis2c-devel bridge-utils coreutils curl curl-devel scsi-target-utils
    perl-Time-HiRes perl-Sys-Virt perl-XML-Simple dejavu-serif-fonts
    device-mapper dhcp dhcp-common e2fsprogs euca2ools
    file gawk httpd iptables iscsi-initiator-utils jpackage-utils
    PyGreSQL libcurl libxml2-devel libxslt-devel lvm2
    m2crypto openssl-devel parted patch perl-Crypt-OpenSSL-RSA
    perl-Crypt-OpenSSL-Random postgresql postgresql-server pv python-boto
    python-devel python-setuptools rampartc rampartc-devel rsync
    scsi-target-utils sudo swig util-linux vconfig velocity wget which
    xalan-j2-xsltc ipset ebtables librbd1 librados2 libselinux-python
    libselinux-utils policycoreutils selinux-policy-base}

# node controller specific deps
el7ncdeps = %w{libvirt libvirt-python kvm qemu-kvm}

el6build = %w{java-1.8.0-openjdk-devel ant ant-junit ant-nodeps apache-ivy
    axis2-adb axis2-adb-codegen axis2c-devel axis2-codegen curl-devel gawk
    git jpackage-utils libvirt-devel libxml2-devel json-c libxslt-devel
    m2crypto openssl-devel python-devel python-setuptools json-c-devel
    rampartc-devel swig xalan-j2-xsltc gengetopt autoconf}

el6runtime = %w{java-1.8.0-openjdk gcc bc make ant ant-nodeps apache-ivy
    axis2-adb-codegen axis2-codegen axis2c axis2c-devel bridge-utils
    coreutils curl curl-devel scsi-target-utils perl-Time-HiRes perl-Sys-Virt
    perl-XML-Simple dejavu-serif-fonts device-mapper dhcp dhcp-common
    e2fsprogs euca2ools file gawk httpd
    iptables iscsi-initiator-utils jpackage-utils PyGreSQL libcurl
    libxml2-devel libxslt-devel lvm2 m2crypto
    openssl-devel parted patch perl-Crypt-OpenSSL-RSA
    perl-Crypt-OpenSSL-Random postgresql92 postgresql92-server pv
    python-boto python-devel python-setuptools rampartc rampartc-devel rsync
    scsi-target-utils sudo swig util-linux vconfig velocity vtun wget which
    xalan-j2-xsltc ipset ebtables librbd1 librados2 libselinux-python}

# node controller specific deps
el6ncdeps = %w{libvirt libvirt-python kvm}

# concatenate the runtime and build deps, remove dups, and sort
el7deps = el7runtime.concat(el7build).uniq().sort()
el6deps = el6runtime.concat(el6build).uniq().sort()

if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  el6deps.each do |dependency|
    yum_package dependency do
      options node['eucalyptus']['yum-options']
      action :upgrade
    end
  end
  exp_run_list = node['expanded_run_list']
  exp_run_list.each do |listitem|
    if listitem.include? "node-controller"
      Chef::Log.info "Installing node-controller specific packages (these packages should not be installed on all service machines)"
      el6ncdeps.each do |dependency|
        yum_package dependency do
          options node['eucalyptus']['yum-options']
          action :upgrade
        end
      end
    end
  end
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  el7deps.each do |dependency|
    yum_package dependency do
      options node['eucalyptus']['yum-options']
      action :upgrade
    end
  end
  exp_run_list = node['expanded_run_list']
  exp_run_list.each do |listitem|
    if listitem.include? "node-controller"
      Chef::Log.info "Installing node-controller specific packages (these packages should not be installed on all service machines)"
      el7ncdeps.each do |dependency|
        yum_package dependency do
          options node['eucalyptus']['yum-options']
          action :upgrade
        end
      end
    end
  end
end

source_directory = "#{node['eucalyptus']["home-directory"]}/source"

directory source_directory do
  recursive true
  action :delete
  only_if "#{node['eucalyptus']['rm-source-dir']}"
end

directory source_directory do
  action :create
end

make_install = "make && make install"
_prefix = "/usr"
_configure = "./configure"
java_home = "export JAVA_HOME=/usr/lib/jvm/java-1.8.0 && \
export JAVA=$JAVA_home/jre/bin/java"


###############################
# Install eucalyptus-cloud-libs
###############################

cloud_libs_dir = "#{source_directory}/eucalyptus-cloud-libs"
git cloud_libs_dir do
  repository node['eucalyptus']['cloud-libs-repo']
  revision node['eucalyptus']['cloud-libs-branch']
  action :sync
  notifies :run, 'execute[install-cloud-libs]', :immediately
end

build_cloud_libs = "autoconf && #{_configure} --prefix=#{_prefix} && \
#{make_install}"
execute "install-cloud-libs" do
  command build_cloud_libs
  cwd cloud_libs_dir
  action :nothing
end

####################
# Install eucalyptus
####################

eucalyptus_dir = "#{source_directory}/eucalyptus"
git eucalyptus_dir do
  repository node['eucalyptus']['source-repo']
  revision node['eucalyptus']['source-branch']
  action :sync
  notifies :run, 'execute[install-eucalyptus]', :immediately
end

db_home_path = "/usr"
init_style = "--enable-systemd"

if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  db_home_path = "/usr/pgsql-9.2"
  init_style = "--enable-sysvinit"
end

build_eucalyptus = "#{java_home} && #{_configure} --prefix=/ \
--disable-bundled-jars #{init_style} \
--with-apache2-module-dir=/usr/lib64/httpd/modules \
--with-axis2=/usr/share/axis2-* --with-axis2c=/usr/lib64/axis2c \
--with-db-home=#{db_home_path} && #{make_install}"

execute "install-eucalyptus" do
  command build_eucalyptus
  cwd eucalyptus_dir
  action :nothing
end


##########################
# Install storage-san-libs
##########################

san_libs_dir = "#{source_directory}/storage-san-libs"
git san_libs_dir do
  repository node['eucalyptus']['san-libs-repo']
  revision node['eucalyptus']['san-libs-branch']
  action :sync
  notifies :run, 'execute[install-san-libs]', :immediately
  only_if { Eucalyptus::Enterprise.is_san?(node) }
end

build_san_libs = "autoconf && #{_configure} --prefix=#{_prefix} && #{make_install}"
execute "install-san-libs" do
  command build_san_libs
  cwd san_libs_dir
  action :nothing
end


#####################
# Install storage-san
#####################

storage_san_dir = "#{source_directory}/storage-san"
git storage_san_dir do
  repository node['eucalyptus']['san-repo']
  revision node['eucalyptus']['san-branch']
  action :sync
  notifies :run, 'execute[install-storage-san]', :immediately
  only_if { Eucalyptus::Enterprise.is_san?(node) }
end

build_storage_san = "autoconf && #{_configure} --prefix=#{_prefix} \
--with-cloud-libs-dir=/usr/share/eucalyptus && #{make_install}"
execute "install-storage-san" do
  command build_storage_san
  cwd storage_san_dir
  action :nothing
end


############################
# Install eucalyptus-selinux
############################

build_selinux_command = "make all && make reload && make relabel"
execute "Build and install eucalyptus-selinux" do
  command build_selinux_command
  cwd "#{node['eucalyptus']["home-directory"]}/source/eucalyptus-selinux"
  action :nothing
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  db_home_path = "/usr"
  init_style = "--enable-systemd"
  git "#{node['eucalyptus']["home-directory"]}/source/eucalyptus-selinux" do
    repository "https://github.com/eucalyptus/eucalyptus-selinux"
    action :sync
    notifies :run, 'execute[Build and install eucalyptus-selinux]', :immediately
  end
end

if node['eucalyptus']['source-repo'].include? "internal"
  euca_wsdl_path = "#{source_directory}/eucalyptus/devel/euca-WSDL2C.sh"
else
  euca_wsdl_path = "#{source_directory}/devel/euca-WSDL2C.sh"
end

execute "echo \"export PATH=$PATH:#{home_directory}/usr/sbin/\" >>/root/.bashrc"

%w{/etc/eucalyptus /var/lib/eucalyptus /var/log/eucalyptus /var/run/eucalyptus}.each do |runtime_dir|
  execute "mkdir -p #{home_directory}/#{runtime_dir}"
  execute "chown -R eucalyptus:eucalyptus #{home_directory}/#{runtime_dir}"
end

%w{/usr/lib/eucalyptus/euca_mountwrap /usr/lib/eucalyptus/euca_rootwrap}.each do |suid_exe|
  file suid_exe do
    mode '4755'
    group 'eucalyptus'
  end
end

if node['eucalyptus']['source-repo'].end_with?("internal")
  eucalyptus_dir = "#{source_directory}/eucalyptus"
end

tools_dir = "#{eucalyptus_dir}/tools"

if node["eucalyptus"]["network"]["mode"] == "EDGE"
  execute "ln -sf #{tools_dir}/eucanetd /etc/init.d/eucanetd" do
    creates "/etc/init.d/eucanetd"
  end
  execute "chmod +x #{tools_dir}/eucanetd"
end

execute "Copy Policy Kit file for NC" do
  command "cp #{tools_dir}/eucalyptus-nc-libvirt.pkla /var/lib/polkit-1/localauthority/10-vendor.d/"
end

### Add udev rules
directory '/etc/udev/rules.d'
directory '/etc/udev/scripts'
udev_mapping = {'clc/modules/block-storage-common/udev/55-openiscsi.rules' => '/etc/udev/rules.d/55-openiscsi.rules',
                'clc/modules/block-storage-common/udev/iscsidev.sh' => '/etc/udev/scripts/iscsidev.sh',
                'clc/modules/block-storage/udev/rules.d/12-dm-permissions.rules' => '/etc/udev/rules.d/12-dm-permissions.rules'}
udev_mapping.each do |src, dst|
  execute "cp #{eucalyptus_dir}/#{src} #{dst}"
end

execute 'run \'modprobe kvm_intel\' to set permissions of /dev/kvm correctly' do
  command 'modprobe kvm_intel'
  only_if { ::File.exist? "/usr/lib/udev/rules.d/80-kvm.rules" }
end
