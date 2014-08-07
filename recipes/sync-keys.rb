#
# Cookbook Name:: eucalyptus
# Recipe:: sync-keys
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

ruby_block "Synchronize cloud keys" do
  block do
    if node.recipe?("eucalyptus::walrus") or node.recipe?("eucalyptus::user-facing")
      Eucalyptus::KeySync.get_cloud_keys(node)
    end
    if node.recipe?("eucalyptus::storage-controller")
      Eucalyptus::KeySync.get_cluster_keys(node, "sc-1")
    end
    if node.recipe?("eucalyptus::node-controller")
      Eucalyptus::KeySync.get_node_keys(node)
    end
    if node.recipe?("eucalyptus::cluster-controller")
      Eucalyptus::KeySync.get_cluster_keys(node, "cc-1")
      cluster_name = Eucalyptus::KeySync.get_local_cluster_name(node)
      nc_ips = node['eucalyptus']['topology']['clusters'][cluster_name]['nodes'].split()
      Chef::Log.info "Node list is: #{nc_ips}"
      nc_ips.each do |nc_ip|
        r = Chef::Resource::Execute.new('Register Nodes', node.run_context)
        r.command "#{node['eucalyptus']['home-directory']}/usr/sbin/euca_conf --register-nodes #{nc_ip} --no-scp --no-rsync --no-sync"
        r.run_action :run
      end
    end
  end
  not_if "#{Chef::Config[:solo]}"
end
