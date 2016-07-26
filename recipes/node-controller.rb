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

# used for platform_version comparison
require 'chef/version_constraint'

include_recipe "eucalyptus::default"

source_directory = "#{node['eucalyptus']["home-directory"]}/source/#{node['eucalyptus']['source-branch']}"

if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  nodecontrollerservice = "service[eucalyptus-nc]"
end
if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  nodecontrollerservice = "service[eucalyptus-node]"
end


# this runs only during installation of eucanetd,
# we don't handle reapplying changed ipset max_sets
# during an update here
if node["eucalyptus"]["network"]["mode"] == "EDGE"
  maxsets = node["eucalyptus"]["nc"]["ipset-maxsets"]
  # install ipset if necessary
  execute 'yum install -y ipset' do
    not_if "rpm -q ipset"
  end
  execute 'unload-ipset-hash-net' do
    command 'rmmod ip_set_hash_net'
    ignore_failure true
    action :nothing
    only_if 'lsmod | grep ip_set_hash_net'
  end
  execute 'unload-ipset' do
    command 'rmmod ip_set'
    ignore_failure true
    action :nothing
    only_if 'lsmod | grep ip_set'
  end
  execute 'load-ipset' do
    command 'modprobe ip_set'
    action :nothing
  end
  # configure ipset max_sets parameter on NC
  execute "Configure ip_set max_sets options in /etc/modprobe.d/ip_set.conf file" do
    command "echo 'options ip_set max_sets=#{maxsets}' > /etc/modprobe.d/ip_set.conf"
    not_if "grep #{maxsets} /sys/module/ip_set/parameters/max_sets || grep \"options ip_set max_sets=#{maxsets}\" /etc/modprobe.d/ip_set.conf"
    notifies :run, 'execute[unload-ipset-hash-net]', :immediately
    notifies :run, 'execute[unload-ipset]', :immediately
    notifies :run, 'execute[load-ipset]', :immediately
  end
end

## Install packages for the NC
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-nc" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    flush_cache [:before]
    notifies :restart, "#{nodecontrollerservice}", :delayed
  end
else
  include_recipe "eucalyptus::install-source"
end

# make sure libvirt is started now in case
# we want to delete its networks for dhcp conflicts later
service 'libvirtd' do
  action [ :enable, :start ]
end

# only install eucanetd on NC for non vpc modes
if node["eucalyptus"]["network"]["mode"] != "VPCMIDO"
  include_recipe "eucalyptus::eucanetd"
end

if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  if node["eucalyptus"]["network"]["mode"] == "VPCMIDO"
    execute "Set ip_forward sysctl values in sysctl.conf" do
      command "sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf"
    end
    execute "Set bridge-nf-call-iptables sysctl values in sysctl.conf" do
      command "sed -i 's/net.bridge.bridge-nf-call-iptables.*/net.bridge.bridge-nf-call-iptables = 1/' /etc/sysctl.conf"
    end
    execute "Reload sysctl values" do
        command "sysctl -p"
    end
  end
end

# setup subscriber to restart midolman when bridge is created in VPC mode
if node["eucalyptus"]["network"]["mode"] == "VPCMIDO"
  if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
        execute 'midolman-restart' do
            command "service midolman restart"
            action :nothing
            subscribes :run, "execute[ifup-br0]", :immediately
        end
  end
  if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
        execute 'midolman-restart' do
            command "systemctl restart midolman"
            action :nothing
            subscribes :run, "execute[ifup-br0]", :immediately
        end
  end
end

## Setup Bridge EDGE mode only
execute "network-restart" do
  command "service network restart"
  action :nothing
end

## Create bridge in VPCMIDO mode
execute "ifup-br0" do
  command "ifup br0"
  action :nothing
end

network_script_directory = '/etc/sysconfig/network-scripts'
bridged_nic = node["eucalyptus"]["network"]["bridged-nic"]
bridge_interface = node["eucalyptus"]["network"]["bridge-interface"]
bridged_nic_file = "#{network_script_directory}/ifcfg-" + bridged_nic
bridge_file = "#{network_script_directory}/ifcfg-" + bridge_interface
bridged_nic_hwaddr = `cat #{bridged_nic_file} | grep HWADDR`.strip

if node["eucalyptus"]["network"]["mode"] == "VPCMIDO"
  template bridge_file do
    source "ifcfg-br-dhcp-vpcmido.erb"
    mode 0644
    owner "root"
    group "root"
  end
else
  template bridge_file do
    source "ifcfg-br-dhcp.erb"
    mode 0644
    owner "root"
    group "root"
  end
end

# Do not attach bridge to physical NIC in VPCMIDO mode (Issue #314)
if node["eucalyptus"]["network"]["mode"] != "VPCMIDO"
  execute "Copy existing interface config to bridge config" do
    command "cp #{bridged_nic_file} #{bridge_file}"
    not_if "ls #{bridge_file}"
  end

  execute "Add BRIDGE type to bridge file" do
    command "echo 'TYPE=Bridge' >> #{bridge_file}"
    not_if "grep 'TYPE=Bridge' #{bridge_file}"
  end

  execute "Set device name in bridge file" do
    command "sed -i 's/DEVICE.*/DEVICE=#{bridge_interface}/g' #{bridge_file}"
    not_if "grep 'DEVICE=#{bridge_interface}' #{bridge_file}"
  end

  template bridged_nic_file do
    source "ifcfg-eth.erb"
    mode 0644
    owner "root"
    group "root"
  end

  execute "Set HWADDR in bridged nic file" do
    command "echo #{bridged_nic_hwaddr} >> #{bridged_nic_file}"
    not_if "grep '#{bridged_nic_hwaddr}' #{bridged_nic_file}"
  end
end

## use a different notifier to setup bridge in VPCMIDO mode
if node["eucalyptus"]["network"]["mode"] != "VPCMIDO"
  execute "Ensure bridge modules loaded into the kernel on NC" do
    command "modprobe bridge"
    notifies :run, "execute[network-restart]", :immediately
    notifies :run, "execute[brctl setfd]", :delayed
    notifies :run, "execute[brctl sethello]", :delayed
    notifies :run, "execute[brctl stp]", :delayed
  end
else
  execute "Ensure bridge modules loaded into the kernel on NC" do
    command "modprobe bridge"
    notifies :run, "execute[ifup-br0]", :immediately
  end
end

service "messagebus" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
end

## Setup bridge to allow instances to dhcp properly and early on
execute "brctl setfd" do
  command "brctl setfd #{node["eucalyptus"]["network"]["bridge-interface"]} 2"
  action :nothing
end
execute "brctl sethello" do
  command "brctl sethello #{node["eucalyptus"]["network"]["bridge-interface"]} 2"
  action :nothing
end
execute "brctl stp" do
  command "brctl stp #{node["eucalyptus"]["network"]["bridge-interface"]} off"
  action :nothing
end

### Ensure hostname resolves
execute "echo \"#{node[:ipaddress]} \`hostname --fqdn\` \`hostname\`\" >> /etc/hosts" do
  not_if "ping -c \`hostname --fqdn\`"
end

ruby_block "Sync keys for NC" do
  block do
    Eucalyptus::KeySync.get_node_keys(node)
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end


if CephHelper::SetCephRbd.is_ceph?(node)
  directory "/etc/ceph" do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end
end

ruby_block "Set Ceph Credentials" do
  block do
    if node['ceph']
      CephHelper::SetCephRbd.set_ceph_credentials(node, node['ceph']['users'][0]['name'])
    else
      CephHelper::SetCephRbd.set_ceph_credentials(node, "")
    end
  end
  only_if { CephHelper::SetCephRbd.is_ceph?(node) }
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
  notifies :restart, "#{nodecontrollerservice}", :delayed
end

# on el6 the init scripts are named differently than on el7
# systemctl does not like unit files which are symlinks
# so we will use the actual unit file names here
if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  service "eucalyptus-nc" do
    action [ :enable ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  service "eucalyptus-node" do
    action [ :enable ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end
