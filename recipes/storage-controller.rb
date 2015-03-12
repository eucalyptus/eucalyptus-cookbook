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


if CephHelper::SetCephRbd.is_ceph?(node)
  directory "/etc/ceph" do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end
end


if Eucalyptus::Enterprise.is_san?(node)
  node['eucalyptus']['topology']['clusters'].each do |cluster, info|
    case info['storage-backend']
    when 'emc-vnx'
      san_package = 'eucalyptus-enterprise-storage-san-emc'
      navicli_package = "#{Chef::Config[:file_cache_path]}/NaviCLI-Linux-64-x86-en_US.rpm"
      remote_file navicli_package do
        source node["eucalyptus"]["storage"]["emc"]["navicli-url"]
      end
      yum_package "NaviCLI-Linux-64-x86-en_US" do
        action :install
        source navicli_package
        options node['eucalyptus']['yum-options']
      end
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
    if Eucalyptus::Enterprise.is_vmware?(node)
      yum_package 'eucalyptus-enterprise-vmware-broker-libs' do
        action :upgrade
        options node['eucalyptus']['yum-options']
        notifies :restart, "service[eucalyptus-cloud]", :immediately
        flush_cache [:before]
      end
    end
  end
end

ruby_block "Sync keys for SC" do
  block do
    Eucalyptus::KeySync.get_cluster_keys(node, "sc-1")
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end

ruby_block "Get Ceph Credentials" do
  block do
    CephHelper::SetCephRbd.make_ceph_config(node)
  end
  only_if { CephHelper::SetCephRbd.is_ceph?(node) }
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

