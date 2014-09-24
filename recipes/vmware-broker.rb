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


## Install packages for the VB
%w{eucalyptus-enterprise-vmware-broker}.each do |pkg|
  yum_package pkg do
    action :upgrade
    options node['eucalyptus']['yum-options']
    flush_cache [:before]
    notifies :restart, 'service[eucalyptus-cloud]', :immediately
  end
end

ruby_block "Sync keys for VMware Broker" do
  block do
    Eucalyptus::KeySync.get_cloud_keys(node)
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
