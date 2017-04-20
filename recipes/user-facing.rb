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
require "json"

return if node.recipe?("eucalyptus::cloud-controller")

include_recipe "eucalyptus::cloud-service"

yum_package "ceph-radosgw" do
  action :upgrade
  options node['eucalyptus']['yum-options']
  flush_cache [:before]
  only_if { CephHelper::SetCephRbd.is_ceph_radosgw?(node) }
end

if CephHelper::SetCephRbd.is_ceph_radosgw?(node)
  ceph_config = CephHelper::SetCephRbd.get_configurations(
  node["eucalyptus"]["topology"]["objectstorage"]["ceph-config"],
  node["eucalyptus"]["ceph-config"])

  ceph_radosgw = CephHelper::SetCephRbd.get_configurations(
  node['eucalyptus']["topology"]["objectstorage"]['ceph-radosgw'],
  node['eucalyptus']['ceph-radosgw'])
end

template "/etc/ceph/ceph.conf" do
  source "ceph.conf.erb"
  owner 'ceph'
  group 'ceph'
  mode '0644'
  action :create
  variables(
    :cephConfig => ceph_config,
    :cephRadosGW => ceph_radosgw
  )
  only_if { CephHelper::SetCephRbd.is_ceph_radosgw?(node) }
end

if CephHelper::SetCephRbd.is_ceph_radosgw?(node)
  ceph_keyrings = CephHelper::SetCephRbd.get_configurations(
  node['eucalyptus']["topology"]["objectstorage"]['ceph-keyrings'],
  node['eucalyptus']['ceph-keyrings'])

  %w{admin radosgw bootstrap-rgw}.each do |ceph_user_keyring|
    if ceph_keyrings[ceph_user_keyring]
      template "#{ceph_keyrings[ceph_user_keyring]["keyring"]}" do
        source "client-keyring.erb"
        owner 'ceph'
        group 'ceph'
        mode '0600'
        variables(
          :keyring => ceph_keyrings[ceph_user_keyring]
        )
        action :create
      end
    else
      raise Exception.new("Unable to create keyring file for #{ceph_user_keyring}!!!")
    end
  end
end

# TODO make sure when multiple UFS is present, ceph user created once
ruby_block "Create New Ceph User" do
  block do
    if node['eucalyptus']['topology']['objectstorage']['access-key'] == nil ||
      node['eucalyptus']['topology']['objectstorage']['secret-key'] == nil
      if node['eucalyptus']['topology']['objectstorage']['ceph-radosgw']['username']
        new_username = node['eucalyptus']['topology']['objectstorage']['ceph-radosgw']['username']
      else
        raise Exception.new("'username' not found in node['eucalyptus']['topology']['objectstorage']['ceph-radosgw']")
      end
      Chef::Log.info "ACCESS_KEY and/or SECRET_KEY not found. Creating new user: #{new_username}"
      cmd = "radosgw-admin user create --uid=#{new_username} --display-name=#{new_username}"
      shell = Mixlib::ShellOut.new(cmd)
      shell.run_command
      if !shell.exitstatus
        raise "#{cmd} failed: " + shell.stdout + ", " + shell.stderr
      end
      new_user = JSON.parse(shell.stdout)
      node.set['eucalyptus']['topology']['objectstorage']['access-key'] = new_user['keys'][0]['access_key']
      node.set['eucalyptus']['topology']['objectstorage']['secret-key'] = new_user['keys'][0]['secret_key']
      node.save
    end
  end
  only_if { CephHelper::SetCephRbd.is_ceph_radosgw?(node) }
end

ruby_block "Sync keys for User Facing Services" do
  block do
    Eucalyptus::KeySync.get_cloud_keys(node)
  end
  only_if { node['eucalyptus']['sync-keys'] }
end

service "ufs-eucalyptus-cloud" do
  service_name "eucalyptus-cloud"
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

service "ceph-radosgw@rgw.euca-osg" do
  action [:enable, :start]
  supports :status => true, :start => true, :stop => true, :restart => true
  retries 3
  retry_delay 10
  only_if { CephHelper::SetCephRbd.is_ceph_radosgw?(node) }
end
