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
#
include_recipe "eucalyptus::default"
## Install binaries for the CC
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-cc" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    flush_cache [:before]
    notifies :restart, "service[eucalyptus-cc]", :immediately
  end
  ### Compat for 3.4.2 and 4.0.0
  yum_package "dhcp"
else
  include_recipe "eucalyptus::install-source"
end

node["eucalyptus"]["topology"]["clusters"].each do |name, info|
  log "Found cluster #{name} with attributes: #{info}"
  addresses = []
  node["network"]["interfaces"].each do |interface, info|
    info["addresses"].each do |address, info|
      addresses.push(address)
    end
  end
  log "Found addresses: " + addresses.join(",")
  if addresses.include?(info["cc-1"]) and not Chef::Config[:solo]
      node.set["eucalyptus"]["local-cluster-name"] = name
      node.save
  end
  log "Using cluster name: " + node["eucalyptus"]["local-cluster-name"]
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
end

execute "export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --setup"

ruby_block "Get cluster keys from CLC" do
  block do
    local_cluster_name = node["eucalyptus"]["local-cluster-name"]
    if node["eucalyptus"]["topology"]["clc-1"] != ""
      ### CLC is seperate
      clc_ip = node["eucalyptus"]["topology"]["clc-1"]
      clc  = search(:node, "addresses:#{clc_ip}").first
      node.set["eucalyptus"]["cloud-keys"][local_cluster_name] = clc["eucalyptus"]["cloud-keys"][local_cluster_name]
    else
      node.set["eucalyptus"]["topology"]["clusters"][local_cluster_name]["cc-1"] = node["ipaddress"]
      node.set["eucalyptus"]["cloud-keys"][local_cluster_name] = node["eucalyptus"]["cloud-keys"][local_cluster_name]
    end
    node.save
    node["eucalyptus"]["cloud-keys"][local_cluster_name].each do |key_name,data|
     file_name = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{key_name}"
     if data.is_a?(String)
       File.open(file_name, 'w') do |file|
         file.puts Base64.decode64(data)
       end
     end
     require 'fileutils'
     FileUtils.chmod 0700, file_name
     FileUtils.chown 'eucalyptus', 'eucalyptus', file_name
    end
  end
  not_if "#{Chef::Config[:solo]}"
end

service "eucalyptus-cc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
