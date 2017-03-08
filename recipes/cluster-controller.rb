#
# Cookbook Name:: eucalyptus
# Recipe:: default
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
#

include_recipe "eucalyptus::default"

clustercontrollerservice = "service[eucalyptus-cluster]"

## Install binaries for the CC
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-cc" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    flush_cache [:before]
    notifies :restart, "#{clustercontrollerservice}", :delayed
  end
  ### Compat for 3.4.2 and 4.0.0
  yum_package "dhcp"
else
  include_recipe "eucalyptus::install-source"
end

template "eucalyptus.conf" do
  path   "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  source "eucalyptus.conf.erb"
  notifies :restart, "#{clustercontrollerservice}", :delayed
  action :create
end

cluster_name = Eucalyptus::KeySync.get_local_cluster_name(node)

node.set["eucalyptus"]["nodes"] = node["eucalyptus"]["topology"]["clusters"][cluster_name]["nodes"]
node.save

ruby_block "Sync keys for CC" do
  block do
    Eucalyptus::KeySync.get_cluster_keys(node, "cc")
  end
  only_if { node['eucalyptus']['sync-keys'] }
end

execute "Ensure bridge modules loaded into the kernel on CC" do
  command "modprobe bridge"
end

network_mode = node["eucalyptus"]["network"]["mode"]
if network_mode == "MANAGED" or network_mode == "MANAGED-NOVLAN"
  include_recipe "eucalyptus::eucanetd"
end

service "eucalyptus-cluster" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

nc_ips = node['eucalyptus']['topology']['clusters'][cluster_name]['nodes']
log "Registering the following nodes: #{nc_ips}"
nc_ips.each do |nc_ip|
  execute 'Register Nodes' do
    command "#{node['eucalyptus']['home-directory']}/usr/sbin/clusteradmin-register-nodes #{nc_ip}"
  end
end
