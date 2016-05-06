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

if node['eucalyptus']['topology']['ceph-radosgw']
  # TODO: write individual recipe for osg and move this section
  if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
    yum_repository "ceph-hammer" do
      description "Ceph Hammer Package Repo"
      url "http://download.ceph.com/rpm-hammer/el6/x86_64/"
      gpgcheck false
    end
  end

  if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
    yum_repository "ceph-hammer" do
      description "Ceph Hammer Package Repo"
      url "http://download.ceph.com/rpm-hammer/el7/x86_64/"
      gpgcheck false
    end
  end

  yum_package "ceph-radosgw" do
    action :upgrade
    flush_cache [:before]
  end

  template "/etc/ceph/ceph.conf" do
    source "ceph.conf.erb"
    action :create
  end

  if node['eucalyptus']['topology']['ceph-keyrings']['radosgw']
    radosgw = node['eucalyptus']['topology']['ceph-keyrings']['radosgw']
    template "#{radosgw['keyring']}" do
      source "client-keyring.erb"
      variables(
        :keyring => radosgw
      )
      action :create
    end
  end

  service "ceph-radosgw" do
    service_name "ceph-radosgw"
    action [ :enable, :start ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end

ruby_block "Sync keys for User Facing Services" do
  block do
    Eucalyptus::KeySync.get_cloud_keys(node)
  end
  only_if { not Chef::Config[:solo] and node['eucalyptus']['sync-keys'] }
end

service "ufs-eucalyptus-cloud" do
  service_name "eucalyptus-cloud"
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
