#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
#© Copyright 2014-2016 Hewlett Packard Enterprise Development Company LP
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

# used for platform_version comparison
require 'chef/version_constraint'

include_recipe "eucalyptus::default"

source_directory = "#{node['eucalyptus']["home-directory"]}/source/#{node['eucalyptus']['source-branch']}"

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
  eucalyptus_dir = source_directory
  if node['eucalyptus']['source-repo'].end_with?("internal")
    eucalyptus_dir = "#{source_directory}/eucalyptus"
  end
  if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
    tools_dir = "#{eucalyptus_dir}/tools"
    execute "ln -sf #{tools_dir}/eucalyptus-cloud /etc/init.d/eucalyptus-cc" do
      creates "/etc/init.d/eucalyptus-cc"
    end
    execute "chmod +x #{tools_dir}/eucalyptus-cloud"
  end
  if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
    file '/usr/lib/systemd/system/eucalyptus-cluster.service' do
      lazy { content IO.read("#{eucalyptus_dir}/systemd/units/eucalyptus-cluster.service") }
      mode '0644'
      action :create
      not_if do ::File.exists?('/usr/lib/systemd/system/eucalyptus-cluster.service') end
    end
    execute "ln -sf /usr/lib/systemd/system/eucalyptus-cluster.service /usr/lib/systemd/system/eucalyptus-cc.service" do
      creates "/usr/lib/systemd/system/eucalyptus-cc.service"
      not_if do ::File.exists?('/usr/lib/systemd/system/eucalyptus-cc.service') end
    end
  end
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

network_mode = node["eucalyptus"]["network"]["mode"]
if network_mode == "MANAGED" or network_mode == "MANAGED-NOVLAN"
  include_recipe "eucalyptus::eucanetd"
end

# on el6 the init scripts are named differently than on el7
# systemctl does not like unit files which are symlinks
# so we will use the actual unit file names here
if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  service "eucalyptus-cc" do
    action [ :enable, :start ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  service "eucalyptus-cluster" do
    action [ :enable, :start ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end

nc_ips = node['eucalyptus']['topology']['clusters'][cluster_name]['nodes'].split()
log "Registering the following nodes: #{nc_ips}"
nc_ips.each do |nc_ip|
  execute 'Register Nodes' do
    command "#{node['eucalyptus']['home-directory']}/usr/sbin/clusteradmin-register-nodes #{nc_ip}"
  end
end
