#
# Cookbook Name:: eucalyptus
# Recipe:: register-components
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

##### Register nodes
cluster = node["eucalyptus"]["topology"]["clusters"][node["eucalyptus"]["local-cluster-name"]]
if cluster['nodes'] == ""
  nodes = node["ipaddress"]
else
  nodes = cluster['nodes']
end

ruby_block "Save node list" do
  block do
    node.set["eucalyptus"]["topology"]["clusters"][node["eucalyptus"]["local-cluster-name"]]["nodes"] = nodes
    node.save
  end
  not_if "#{Chef::Config[:solo]}"
end

nodes.split().each do |nc_ip|
  execute "Register Nodes" do
    command "#{node['eucalyptus']['home-directory']}/usr/sbin/euca_conf --register-nodes #{nc_ip} --no-scp --no-rsync --no-sync"
  end
end

