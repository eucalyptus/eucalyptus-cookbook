#
# Cookbook Name:: eucalyptus
# Recipe:: nuke
#
# © Copyright 2014-2016 Hewlett Packard Enterprise Development Company LP
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

## Stop all euca components

# on el6 the init scripts are named differently than on el7
# and systemctl does not like to enable unit files which are symlinks
# so we will use the actual unit file here
if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  service "eucalyptus-nc" do
    action [ :stop ]
  end
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  service "eucalyptus-node" do
    action [ :stop ]
  end
end

if node['eucalyptus']['network']['mode'] == 'EDGE' || node['eucalyptus']['network']['mode'] == 'VPCMIDO'
  service "eucanetd" do
    action [ :stop ]
  end
end

execute "Clear all-networking for VPC cloud" do
  command "eucanetd -Z"
  ignore_failure true
end

# on el6 the init scripts are named differently than on el7
# and systemctl does not like to enable unit files which are symlinks
# so we will use the actual unit file here
if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  service "eucalyptus-cc" do
    action [ :stop ]
  end
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  service "eucalyptus-cluster" do
    action [ :stop ]
  end
end

service "eucaconsole" do
  action [ :stop ]
end

service "eucalyptus-cloud" do
  action [ :stop ]
end

## Destroy all running VMs
execute 'Destroy VMs' do
  command "virsh list | grep 'running$' | sed -re 's/^\\s*[0-9-]+\\s+(.*?[^ ])\\s+running$/\"\\1\"/' | xargs -r -n 1 -P 1 virsh destroy"
end

## Purge all Packages
%w{euca2ools python-eucadmin.noarch python-requestbuilder}.each do |pkg|
  yum_package pkg do
    action :purge
  end
end

## Remove euca packages chef yum_package does not seem to like wildcard
execute 'remove euca packages' do
  command "yum -y remove 'euca*'"
end

## remove ceph packages and credentials
service "ceph-radosgw" do
  action :stop
  ignore_failure true
end
%w{ceph-radosgw ceph-common python-cephfs libcephfs1}.each do |ceph_pkg|
  yum_package ceph_pkg do
    action :purge
  end
end
execute 'Remove ceph creds' do
  command 'rm -rf /etc/ceph'
end

bash "Remove devmapper and losetup entries" do
  code <<-EOH
    for export in `tgtadm --lld iscsi -m target -o show | grep Target | grep eucalyptus | awk 'BEGIN{FS="Target";}{print $2}'| awk 'BEGIN{FS=":";}{print $1}'`;do
      tgtadm --lld iscsi -m target -o delete -t $export --force;
    done
  EOH
  only_if "which tgtadm && tgtadm --lld iscsi -m target -o show"
end

bash 'Remove Euca logical volumes' do
  code <<-EOH
    for vol in `lvdisplay  | grep /dev | grep euca-vol- | awk '{print $3}'`;do
      lvremove -f $vol;
    done
  EOH
  only_if "lvdisplay  | grep /dev | grep euca-vol-"
end

## Delete home directory
if node['eucalyptus']['home-directory'] != '/'
  directory node['eucalyptus']['home-directory'] do
    recursive true
    action :delete
  end
end

## Remove repo rpms
yum_repository 'eucalyptus' do
  description 'Eucalyptus Package Repo'
  url node['eucalyptus']['eucalyptus-repo']
  gpgkey node['eucalyptus']['eucalyptus-gpg-key']
  action :remove
end

yum_repository 'eucalyptus-enterprise' do
  description 'Eucalyptus Enterprise Package Repo'
  url node['eucalyptus']['enterprise-repo']
  gpgkey node['eucalyptus']['eucalyptus-gpg-key']
  action :remove
end

yum_repository 'euca2ools' do
  description 'Euca2ools Package Repo'
  url node['eucalyptus']['euca2ools-repo']
  gpgkey node['eucalyptus']['euca2ools-gpg-key']
  action :remove
end

yum_repository 'eucalyptus-release' do
  description 'Eucalyptus Package Repo'
  url node['eucalyptus']['eucalyptus-repo']
  gpgkey node['eucalyptus']['eucalyptus-gpg-key']
  action :remove
end

yum_repository 'eucalyptus-enterprise-release' do
  description 'Eucalyptus Enterprise Package Repo'
  url node['eucalyptus']['enterprise-repo']
  gpgkey node['eucalyptus']['eucalyptus-gpg-key']
  action :remove
end

yum_repository 'euca2ools-release' do
  description 'Euca2ools Package Repo'
  url node['eucalyptus']['euca2ools-repo']
  gpgkey node['eucalyptus']['euca2ools-gpg-key']
  action :remove
end

if node['eucalyptus']['install-type'] == 'sources'
  ### Remove eucalyptus user
  user 'eucalyptus' do
    supports :manage_home => true
    comment 'Eucalyptus User'
    home '/home/eucalyptus'
    shell '/bin/bash'
    action :remove
  end

  execute 'Remove init script symlinks' do
    command 'rm -rf /etc/init.d/euca*'
  end

  directory "#{node['eucalyptus']['home-directory']}/usr/share/eucalyptus" do
    recursive true
    action :delete
    only_if "ls #{node['eucalyptus']['home-directory']}/usr/share/eucalyptus"
  end

  directory "#{node['eucalyptus']['home-directory']}/source" do
    recursive true
    action :delete
    only_if "ls #{node['eucalyptus']['home-directory']}/source"
  end
end

## Delete File system artifacts
directory "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus" do
  recursive true
  action :delete
  only_if "ls #{node["eucalyptus"]["home-directory"]}/etc/eucalyptus"
end

directory "#{node["eucalyptus"]["home-directory"]}/etc/euca2ools" do
  recursive true
  action :delete
  only_if "ls #{node["eucalyptus"]["home-directory"]}/etc/euca2ools"
end

directory "#{node["eucalyptus"]["home-directory"]}/var/log/eucalyptus" do
  recursive true
  action :delete
  only_if "ls #{node["eucalyptus"]["home-directory"]}/var/log/eucalyptus"
end

directory "#{node["eucalyptus"]["home-directory"]}/var/run/eucalyptus" do
  recursive true
  action :delete
  only_if "ls #{node["eucalyptus"]["home-directory"]}/var/run/eucalyptus"
end

bash "Remove devmapper and losetup entries" do
  code <<-EOH
  dmsetup table | grep euca | cut -d':' -f 1 | sort | uniq | xargs -L 1 dmsetup remove
  losetup -a | cut -d':' -f 1 | xargs -L 1 losetup -d
  losetup -a | grep euca
  EOH
  returns 1
  retries 4
  retry_delay 2
end

directory "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus" do
  recursive true
  action :delete
  only_if "ls #{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus"
end

execute "remove all temporary release directories" do
  command "rm -rf /tmp/*release*"
  ignore_failure true
end

execute 'clean iscsi sessions' do
  command 'iscsiadm -m session -u'
  action :run
  returns [ 0, 21 ]
  only_if "which iscsiadm"
end

execute 'delete tgtdadm eucalyptus account' do
  command 'tgtadm --mode account --op delete --user eucalyptus'
  only_if 'tgtadm --mode account --op show | grep eucalyptus'
end

directory "/var/chef/cache" do
  recursive true
  action :delete
  only_if "ls /var/chef/cache"
end

execute "remove all eucalyptus cache repositories" do
  command "rm -rf /var/cache/yum/x86_64/6/euca*"
  ignore_failure true
end

execute "Clear yum cache" do
  command "yum clean all"
end

execute "Remove admin credentials" do
  command "rm -rf /root/.euca/faststart.ini"
  ignore_failure true
  only_if { ::File.exist? "/root/.euca/faststart.ini" }
end
