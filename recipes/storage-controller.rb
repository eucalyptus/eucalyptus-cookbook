#
# Cookbook Name:: eucalyptus
# Recipe:: default
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
# used for platform_version comparison
require 'chef/version_constraint'

include_recipe "eucalyptus::default"

### Need to know cluster name before setting bind-addr

### Set bind-addr if necessary
if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  if node["eucalyptus"]["bind-interface"]
    # Auto detect IP from interface name
    bind_addr = Eucalyptus::BindAddr.get_bind_interface_ip(node)
  else
    # Use default gw interface IP
    bind_addr = node["ipaddress"]
  end
  node.override['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + bind_addr
end

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-sc" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    notifies :create, "template[eucalyptus.conf]"
    flush_cache [:before]
  end
else
  include_recipe "eucalyptus::install-source"
end

template "eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  path "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  action :create
end


if CephHelper::SetCephRbd.is_ceph?(node)
  directory "/etc/ceph" do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end
end


if Eucalyptus::Enterprise.is_san?(node)
  node['eucalyptus']['topology']['clusters'].each do |cluster, info|
    case info['storage-backend']
    when 'emc-vnx'
      san_package = 'eucalyptus-enterprise-storage-san-emc'
      navicli_package = "#{Chef::Config[:file_cache_path]}/NaviCLI-Linux-64-x86-en_US.rpm"
      remote_file navicli_package do
        source node["eucalyptus"]["storage"]["emc"]["navicli-url"]
      end
      yum_package "NaviCLI-Linux-64-x86-en_US" do
        action :install
        source navicli_package
        options node['eucalyptus']['yum-options']
      end
    when 'netapp'
      san_package = 'eucalyptus-enterprise-storage-san-netapp'
    when 'equallogic'
      san_package = 'eucalyptus-enterprise-storage-san-equallogic'
    when 'threepar'
      san_package = 'eucalyptus-enterprise-storage-san-threepar'
    else
      # This cluster is not SAN backed
      san_package = nil
    end
    if node["eucalyptus"]["install-type"] == "packages"
      if san_package
        yum_package san_package do
          action :upgrade
          options node['eucalyptus']['yum-options']
          flush_cache [:before]
        end
      end
    end
  end
end

ruby_block "Sync keys for SC" do
  block do
    Eucalyptus::KeySync.get_cluster_keys(node, "sc-1")
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end

ruby_block "Get Ceph Credentials" do
  block do
    if node['ceph']
      CephHelper::SetCephRbd.make_ceph_config(node, node['ceph']['users'][0]['name'])
    else
      CephHelper::SetCephRbd.make_ceph_config(node, "")
    end
  end
  only_if { CephHelper::SetCephRbd.is_ceph?(node) }
end

node['eucalyptus']['topology']['clusters'].each do |cluster, info|
  Chef::Log.warn("Checking SC bindaddr: #{bind_addr}, ip:#{node["ipaddress"]}, backend:#{info['storage-backend']}, against sc-1:#{info['sc-1']}")
  if (info['storage-backend'] == 'das' or info['storage-backend'] == 'overlay') and (info['sc-1'] == bind_addr or info['sc-1'] == node["ipaddress"])
    Chef::Log.info("Enabling tgtd service for storage controller at: #{bind_addr}, backend:#{info['storage-backend']}")
    service 'tgtd' do
      action [ :enable, :start ]
      supports :status => true, :start => true, :stop => true, :restart => true
    end 
  end 
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  execute "setsebool eucalyptus_storage_controller true" do
    command "/usr/sbin/setsebool -P eucalyptus_storage_controller 1"
  end
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
