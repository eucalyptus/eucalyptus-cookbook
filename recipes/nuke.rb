#
# Cookbook Name:: eucalyptus
# Recipe:: nuke
#
# Copyright 2014, Eucalyptus
#
# All rights reserved - Do Not Redistribute
#
## Stop all euca components
execute 'Stop any running nc process' do
  command 'service eucalyptus-nc stop || true'
end

execute 'Stop any running cc process' do
  command 'service eucalyptus-cc stop || true'
end

execute 'Stop any running cloud process' do
  command 'service eucalyptus-cloud stop || true'
end

## Destroy all running VMs
execute 'Destroy VMs' do
  command "virsh list | grep 'running$' | sed -re 's/^\\s*[0-9-]+\\s+(.*?[^ ])\\s+running$/\"\\1\"/' | xargs -r -n 1 -P 1 virsh destroy"
end

## Purge all Packages
%w{euca2ools 'eucalyptus*' python-eucadmin.noarch}.each do |pkg|
  yum_package pkg do
    action :purge
  end
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
  gpgkey 'http://www.eucalyptus.com/sites/all/files/c1240596-eucalyptus-release-key.pub'
  action :remove
end

yum_repository 'euca2ools-release' do
  description 'Euca2ools Package Repo'
  url node['eucalyptus']['euca2ools-repo']
  gpgkey 'http://www.eucalyptus.com/sites/all/files/c1240596-eucalyptus-release-key.pub'
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

  ### Checkout Eucalyptus Source
  execute 'Checkout source' do
    cwd node['eucalyptus']['home-directory']
    command "git clone #{node['eucalyptus']['source-repo']} -b #{node['eucalyptus']['source-branch']} source"
  end

  execute 'Init submodules' do
    cwd "#{node['eucalyptus']['home-directory']}/source"
    command 'git submodule init && git submodule update'
  end

  directory node['eucalyptus']['home-directory']/source do
    recursive true
    action :delete
  end

  yum_repository 'euca-vmware-libs' do
    description 'VDDK libs repo'
    url node['eucalyptus']['vddk-libs-repo']
    action :remove
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/vmware-broker"
  end
end

## Delete File system artifacts
directory '/etc/eucalyptus' do
  recursive true
  action :delete
  only_if 'ls /etc/eucalyptus'
end

directory '/etc/euca2ools' do
  recursive true
  action :delete
  only_if 'ls /etc/euca2ools'
end

directory '/var/log/eucalyptus' do
  recursive true
  action :delete
  only_if 'ls /var/log/eucalyptus'
end

directory '/var/run/eucalyptus' do
  recursive true
  action :delete
  only_if 'ls /var/run/eucalyptus'
end

directory '/var/lib/eucalyptus' do
  recursive true
  action :delete
  only_if 'ls /var/lib/eucalyptus'
end

directory "#{node['eucalyptus']['home-directory']}/source/vmware-broker" do
  recursive true
  action :delete
  only_if "ls #{node["eucalyptus"]["home-directory"]}/source/vmware-broker"
end

directory '/tmp/*release*' do
  recursive true
  action :delete
  only_if 'ls /tmp/*release*'
end

execute 'clean iscsi sessions' do
  command 'iscsiadm -m session -u'
  action :run
end