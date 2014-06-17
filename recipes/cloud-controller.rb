#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
#Copyright [2014] [Eucalyptus Systems]
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
## Install unzip so we can extract creds
yum_package "unzip" do
  action :upgrade
  options node['eucalyptus']['yum-options']
end

if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  bind_addr = node["ipaddress"]
  node["network"]["interfaces"].each do |if_name, if_info|
    if_info["addresses"].each do |addr, addr_info|
      if node["eucalyptus"]["topology"]["clc-1"].include?(addr)
        bind_addr = addr
      end
    end
  end
  node.set['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + bind_addr
  node.save
end

include_recipe "eucalyptus::cloud-service"

execute "Initialize Eucalyptus DB" do
 command "#{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --initialize"
 creates "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/db/data/server.crt"
end

ruby_block "Upload cloud keys Chef Server" do
  block do
    Eucalyptus::KeySync.upload_cloud_keys(node)
  end
  not_if "#{Chef::Config[:solo]}"
end

if Eucalyptus::Enterprise.is_enterprise?(node)
  if Eucalyptus::Enterprise.is_san?(node)
    node['eucalyptus']['topology']['clusters'].each do |cluster, info|
      case info['storage-backend']
      when 'emc'
        san_package = 'eucalyptus-enterprise-storage-san-emc-libs'
      when 'netapp'
        san_package = 'eucalyptus-enterprise-storage-san-netapp-libs'
      when 'equallogic'
        san_package = 'eucalyptus-enterprise-storage-san-equallogic-libs'
      end
      yum_package san_package do
        action :upgrade
        options node['eucalyptus']['yum-options']
        notifies :restart, "service[eucalyptus-cloud]", :immediately
        flush_cache [:before]
      end
    end
    if Eucalyptus::Enterprise.is_vmware?(node)
      yum_package 'eucalyptus-enterprise-vmware-broker-libs' do
        action :upgrade
        options node['eucalyptus']['yum-options']
        notifies :restart, "service[eucalyptus-cloud]", :immediately
        flush_cache [:before]
      end
    end
  end
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
