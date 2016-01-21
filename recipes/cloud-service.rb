#
# Cookbook Name:: eucalyptus
# Recipe:: cloud-service
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

## Install packages for the User Facing Services
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-cloud" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    notifies :create, "template[eucalyptus.conf]", :immediately
    flush_cache [:before]
  end
else
  include_recipe "eucalyptus::install-source"
end

cookbook_file '/etc/eucalyptus/cloud.d/postgresql-binaries.properties' do
  source 'postgresql-binaries.properties'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

yum_package "euca2ools" do
  action :upgrade
  options node['eucalyptus']['yum-options']
end

if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  if node["eucalyptus"]["bind-interface"]
    # Auto detect IP from interface name
    bind_addr = Eucalyptus::BindAddr.get_bind_interface_ip(node)
  else
    # Use default gw interface IP
    bind_addr = node["ipaddress"]
  end
  node.override['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + bind_addr
end

template "eucalyptus.conf" do
  path   "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  source "eucalyptus.conf.erb"
  action :create
end
