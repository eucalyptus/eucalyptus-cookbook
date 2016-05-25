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

require 'chef/version_constraint'

return if node.recipe?("eucalyptus::cloud-controller")

include_recipe "eucalyptus::cloud-service"


# TODO: write individual recipe for osg and move this section
yum_repository "ceph-hammer" do
  description "Ceph Hammer Package Repo"
  url "http://download.ceph.com/rpm-hammer/el6/x86_64/"
  gpgcheck false
  only_if { Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version']) }
end

yum_repository "ceph-hammer" do
  description "Ceph Hammer Package Repo"
  url "http://download.ceph.com/rpm-hammer/el7/x86_64/"
  gpgcheck false
  only_if { Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version']) }
end

radosgw = node['eucalyptus']['topology']['ceph-keyrings']['radosgw']
adminkeyring = node['eucalyptus']['topology']['ceph-keyrings']['ceph-admin']

yum_package "ceph-radosgw" do
  action :upgrade
  flush_cache [:before]
  only_if { node['eucalyptus']['topology']['ceph-radosgw'] }
end

template "/etc/ceph/ceph.conf" do
  source "ceph.conf.erb"
  action :create
  only_if { node['eucalyptus']['topology']['ceph-radosgw'] }
  notifies :restart, 'service[ceph-radosgw]', :delayed
end

template "#{radosgw['keyring']}" do
  source "client-keyring.erb"
  variables(
    :keyring => radosgw
  )
  action :create
  only_if { node['eucalyptus']['topology']['ceph-keyrings']['radosgw'] }
end

template "#{adminkeyring['keyring']}" do
  source "client-keyring.erb"
  variables(
    :keyring => adminkeyring
  )
  action :create
  only_if { node['eucalyptus']['topology']['ceph-keyrings']['ceph-admin'] }
end

ruby_block "Create New Ceph User" do
  block do
    if node['eucalyptus']['topology']['ceph-radosgw']['username']
      new_username = node['eucalyptus']['topology']['ceph-radosgw']['username']
    else
      raise Exception.new("'username' not found in node['eucalyptus']['topology']['ceph-radosgw']")
    end

    Chef::Log.info "ACCESS_KEY and/or SECRET_KEY not found. Creating new user: #{new_username}"
    new_user = JSON.parse(%x[radosgw-admin user create --uid=#{new_username} --display-name="#{new_username}"])
    node.set['eucalyptus']['topology']['ceph-radosgw']['access-key'] = new_user['keys'][0]['access_key']
    node.set['eucalyptus']['topology']['ceph-radosgw']['secret-key'] = new_user['keys'][0]['secret_key']
    node.save
  end
  only_if { node['eucalyptus']['topology']['ceph-radosgw']['access-key'] == nil || node['eucalyptus']['topology']['ceph-radosgw']['secret-key'] == nil }
end

ruby_block "Sync keys for User Facing Services" do
  block do
    Eucalyptus::KeySync.get_cloud_keys(node)
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end

service "ceph-radosgw" do
  service_name "ceph-radosgw"
  action :nothing
  supports :status => true, :start => true, :stop => true, :restart => true
end

service "ufs-eucalyptus-cloud" do
  service_name "eucalyptus-cloud"
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
