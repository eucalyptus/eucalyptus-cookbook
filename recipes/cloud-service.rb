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
## Install vmware broker libs if needed
if Eucalyptus::Enterprise.is_enterprise?(node)
  if Eucalyptus::Enterprise.is_vmware?(node)
    yum_package 'eucalyptus-enterprise-vmware-broker-libs' do
      action :upgrade
      options node['eucalyptus']['yum-options']
      flush_cache [:before]
    end
  end
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

yum_package "euca2ools" do
  action :upgrade
  options node['eucalyptus']['yum-options']
end

if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  bind_addr = node["ipaddress"]
  node["network"]["interfaces"].each do |if_name, if_info|
    if_info["addresses"].each do |addr, addr_info|
      if node["eucalyptus"]["topology"]["user-facing"].include?(addr)
        bind_addr = addr
      end
    end
  end
  node.override['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + bind_addr
end

template "eucalyptus.conf" do
  path   "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  source "eucalyptus.conf.erb"
  action :create
end
