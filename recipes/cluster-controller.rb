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
    notifies :start, "service[eucalyptus-cc]", :immediately
  end
  ### Compat for 3.4.2 and 4.0.0
  yum_package "dhcp"
else
  include_recipe "eucalyptus::install-source"
end

cluster_name = Eucalyptus::KeySync.get_local_cluster_name(node)
ruby_block "Sync keys for CC" do
  block do
    Eucalyptus::KeySync.get_cluster_keys(node, "cc-1")
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end

template "eucalyptus.conf" do
  path   "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  source "eucalyptus.conf.erb"
  action :create
end

execute "Set ip_forward sysctl values on CC" do
  command "sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf"
end

execute "Set bridge-nf-call-iptables sysctl values on NC" do
  command "sed -i 's/net.bridge.bridge-nf-call-iptables.*/net.bridge.bridge-nf-call-iptables = 1/' /etc/sysctl.conf"
end

execute "Ensure bridge modules loaded into the kernel on NC" do
  command "modprobe bridge"
end

execute "Reload sysctl values" do
  command "sysctl -p"
end

service "eucalyptus-cc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

nc_ips = node['eucalyptus']['topology']['clusters'][cluster_name]['nodes'].split()
log "Registering the following nodes: #{nc_ips}"
nc_ips.each do |nc_ip|
  execute 'Register Nodes' do
    command "#{node['eucalyptus']['home-directory']}/usr/sbin/euca_conf --register-nodes #{nc_ip} --no-scp --no-rsync --no-sync"
  end
end
