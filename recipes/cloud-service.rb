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


if node["eucalyptus"]["set-bind-addr"] 
  if node["eucalyptus"]["bind-interface"] or  node["eucalyptus"]["bind-network"]
    # Auto detect IP from interface name or network membership 
    bind_addr = Eucalyptus::BindAddr.get_bind_interface_ip(node)
  else
    # Use default gw interface IP
    bind_addr = node["ipaddress"]
  end
  node.override['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + bind_addr
end


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

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

yum_package "euca2ools" do
  action :upgrade
  options node['eucalyptus']['yum-options']
end

template "eucalyptus.conf" do
  path   "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  source "eucalyptus.conf.erb"
  action :create
  notifies :restart, "service[eucalyptus-cloud]", :immediately
end
