#
# Cookbook Name:: eucalyptus
# Recipe:: register-nodes
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

if node.recipe?("walrus")
  ruby_block "Get cloud keys for walrus service" do
    block do
      Eucalyptus::KeySync.get_cloud_keys(node)
    end
    not_if "#{Chef::Config[:solo]}"
  end
end

if node.recipe?("user-facing")
  ruby_block "Get cloud keys for user-facing service" do
    block do
      Eucalyptus::KeySync.get_cloud_keys(node)
    end
    not_if "#{Chef::Config[:solo]}"
  end
end

if node.recipe?("cluster-controller") or node.recipe?("storage-controller")
  ruby_block "Sync cluster keys" do
    block do
      Eucalyptus::KeySync.get_cluster_keys(node, "cc-1")
    end
    not_if "#{Chef::Config[:solo]}"
    notifies :restart, "service[eucalyptus-cc]", :immediately
  end
end


if node.recipe?("cluster-controller")
  ruby_block "Register nodes" do
    block do
      nc_nodes = search(:node, "chef_environment:#{node.chef_environment} AND recipe:\"eucalyptus\\:\\:node-controller\"")
      nc_ips = []
      nc_nodes.each do |nc_node|
        nc_ips << nc_node[:ipaddress]
      end
      Chef::Log.info "Node list is: #{@nc_ips}"
      topology = data_bag_item("eucalyptus", "topology")
      topology['clusters'][node["eucalyptus"]["local-cluster-name"]]['nodes'] = nc_ips
      topology.save
      nc_ips.each do |nc_ip|
        r = Chef::Resource::Execute.new('Register Nodes', node.run_context)
        r.command "#{node['eucalyptus']['home-directory']}/usr/sbin/euca_conf --register-nodes #{nc_ip} --no-scp --no-rsync --no-sync"
        r.run_action :run
      end
    end
    not_if "#{Chef::Config[:solo]}"
  end
end

if node.recipe?("node-controller")
  ruby_block "Get node keys from CC" do
    block do
      Eucalyptus::KeySync.get_node_keys(node)
    end
    not_if "#{Chef::Config[:solo]}"
    notifies :restart, "service[eucalyptus-nc]", :immediately
  end
end
