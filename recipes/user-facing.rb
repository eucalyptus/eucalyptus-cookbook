#
# Cookbook Name:: eucalyptus
# Recipe:: user-facing
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

if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  bind_addr = node["ipaddress"]
  node["network"]["interfaces"].each do |if_name, if_info|
    if_info["addresses"].each do |addr, addr_info|
      if node["eucalyptus"]["topology"]["user-facing"].include?(addr)
        bind_addr = addr
      end
    end
  end
  node.set['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + bind_addr
  node.save
end

include_recipe "eucalyptus::cloud-service"

ruby_block "Get cloud keys for user-facing service" do
  block do
    Eucalyptus::KeySync.get_cloud_keys(node)
  end
  not_if "#{Chef::Config[:solo]}"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
