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

### Need to know cluster name before setting bind-addr

### Set bind-addr if necessary
if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  node.override['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + node["eucalyptus"]["topology"]['clusters'][Eucalyptus::KeySync.get_local_cluster_name(node)]["sc-1"]
end

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-sc" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    notifies :create, "template[eucalyptus.conf]"
    notifies :restart, "service[eucalyptus-cloud]", :immediately
    flush_cache [:before]
  end
else
  include_recipe "eucalyptus::install-source"
end

template "eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  path "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  action :create
end

if Eucalyptus::Enterprise.is_san?(node)
  node['eucalyptus']['topology']['clusters'].each do |cluster, info|
    case info['storage-backend']
    when 'emc'
      san_package = 'eucalyptus-enterprise-storage-san-emc'
    when 'netapp'
      san_package = 'eucalyptus-enterprise-storage-san-netapp'
    when 'equallogic'
      san_package = 'eucalyptus-enterprise-storage-san-equallogic'
    end
    yum_package san_package do
      action :upgrade
      options node['eucalyptus']['yum-options']
      notifies :restart, "service[eucalyptus-cloud]", :immediately
      flush_cache [:before]
    end
  end
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
