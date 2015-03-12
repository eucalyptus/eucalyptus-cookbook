#
# Cookbook Name:: eucalyptus
# Recipe:: nuke
#
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

## Stop all euca components
service "eucalyptus-nc" do
  action [ :stop ]
end

if node['eucalyptus']['network']['mode'] == 'EDGE'
  service "eucanetd" do
    action [ :stop ]
  end

  execute "eucanetd -F || true" do
    only_if "which eucanetd"
  end
end

service "eucalyptus-cc" do
  action [ :stop ]
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

if node['eucalyptus']['install-type'] == 'source'
  ### Remove eucalyptus user
  user 'eucalyptus' do
    supports :manage_home => true
    comment 'Eucalyptus User'
    home '/home/eucalyptus'
    shell '/bin/bash'
    action :remove
  end

  ### remove build deps repo
  yum_repository 'euca-build-deps' do
    description 'Eucalyptus Build Dependencies repo'
    url node['eucalyptus']['build-deps-repo']
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

  yum_repository 'euca-vmware-libs' do
    description 'VDDK libs repo'
    url node['eucalyptus']['vddk-libs-repo']
    action :remove
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/vmware-broker"
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

directory "#{node['eucalyptus']['home-directory']}/source/vmware-broker" do
  recursive true
  action :delete
  only_if "ls #{node["eucalyptus"]["home-directory"]}/source/vmware-broker"
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
