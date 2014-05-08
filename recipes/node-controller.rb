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

include_recipe "eucalyptus::default"

## Setup Bridge
template "/etc/sysconfig/network-scripts/ifcfg-" + node["eucalyptus"]["network"]["bridged-nic"] do
  source "ifcfg-eth.erb"
  mode 0644
  owner "root"
  group "root"
end

if node["eucalyptus"]["network"]["bridge-ip"] != ""
  bridge_template = "ifcfg-br0-static.erb"
else
  bridge_template = "ifcfg-br0-dhcp.erb"
end

template "/etc/sysconfig/network-scripts/ifcfg-" + node["eucalyptus"]["network"]["bridge-interface"] do
  source bridge_template
  mode 0644
  owner "root"
  group "root"
  not_if "ls /etc/sysconfig/network-scripts/ifcfg-" + node["eucalyptus"]["network"]["bridge-interface"]
  notifies :run, "execute[network-restart]", :immediately
end

execute "network-restart" do
  command "service network restart"
  action :nothing
end

## Install packages for the NC
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-nc" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    flush_cache [:before]
  end
  if node["eucalyptus"]["network"]["mode"] == "EDGE"
    yum_package "eucanetd" do
      action :upgrade
      options node['eucalyptus']['yum-options']
    end
  end
else
  include_recipe "eucalyptus::install-source"
end

service "messagebus" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end

## Setup bridge to allow instances to dhcp properly and early on
execute "brctl setfd #{node["eucalyptus"]["network"]["bridge-interface"]} 2"
execute "brctl sethello #{node["eucalyptus"]["network"]["bridge-interface"]} 2"
execute "brctl stp #{node["eucalyptus"]["network"]["bridge-interface"]} off"

### Ensure hostname resolves
execute "echo \"#{node[:ipaddress]} \`hostname --fqdn\` \`hostname\`\" >> /etc/hosts"

### Determine local cluster name
if not Chef::Config[:solo]
  ### Look through each cluster
  node["eucalyptus"]["topology"]["clusters"].each do |name, cluster_data|
    ### Try to match all of this NCs interfaces
    node["network"]["interfaces"].each do |interface, iface_data|
      ### Look through each of the addresses on the interfaces
      iface_data["addresses"].each do |address, addr_data|
        ### If my addresss is in the nodes list for this cluster
        if cluster_data["nodes"].include?(address) and not Chef::Config[:solo]
          node.set["eucalyptus"]["local-cluster-name"] = name
          node.save
        end
      end
    end
  end
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
end

ruby_block "Get node keys from CC" do
  block do
    Eucalyptus::KeySync.get_node_keys(node)
  end
  not_if "#{Chef::Config[:solo]}"
end

service "eucalyptus-nc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

if node["eucalyptus"]["network"]["mode"] == "EDGE"
  service "eucanetd" do
    action [ :enable, :start ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end
