#
# Cookbook Name:: eucalyptus
# Recipe:: register-components
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
require 'json'

execute "wait-for-credentials" do
  command "rm -rf admin.zip && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --get-credentials admin.zip && unzip -o admin.zip"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 15
  retry_delay 30
end

ruby_block "Upload cloud keys Chef Server" do
  block do
    Eucalyptus::KeySync.upload_cloud_keys(node)
  end
  not_if "#{Chef::Config[:solo]}"
end

##### Register clusters
clusters = node["eucalyptus"]["topology"]["clusters"]
disable_proxy = 'http_proxy=""'
command_prefix = "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && #{disable_proxy} #{node['eucalyptus']['home-directory']}"
euca_conf = "#{command_prefix}/usr/sbin/euca_conf"
modify_property = "#{command_prefix}/usr/sbin/euca-modify-property"
describe_property = "#{command_prefix}/usr/sbin/euca-describe-properties"
dont_sync_keys = "--no-scp --no-rsync --no-sync"


clusters.each do |cluster, info|
  if info["cc-1"] == ""
    cc_ip = node['ipaddress']
  else
    cc_ip = info["cc-1"]
  end

  execute "Register CC" do
    command "#{euca_conf} --register-cluster -P #{cluster} -H #{cc_ip} -C #{cluster}-cc-1 #{dont_sync_keys}"
    not_if "#{disable_proxy} euca-describe-services | grep #{cluster}-cc-1"
    retries 5
    retry_delay 10
  end
  if info["sc-1"] == ""
    sc_ip = node['ipaddress']
  else
    sc_ip = info["sc-1"]
  end

  execute "Register SC" do
    command "#{euca_conf} --register-sc -P #{cluster} -H #{sc_ip} -C #{cluster}-sc-1 #{dont_sync_keys}"
    not_if "#{disable_proxy} euca-describe-services | grep #{cluster}-sc-1"
  end

  if info["vmware-broker"]
    execute "Register VMware Broker" do
      command "#{euca_conf} --register-vmwarebroker -P #{cluster} -H #{info["vmware-broker"]} -C #{cluster}-vb #{dont_sync_keys}"
      not_if "#{disable_proxy} euca-describe-services | grep #{cluster}-vb"
    end
  end

  #### Sync cluster keys
  cluster_keys_dir = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{cluster}"
  ruby_block "Upload cluster keys Chef Server" do
    block do
      %w(cloud-cert.pem cluster-cert.pem cluster-pk.pem node-cert.pem node-pk.pem vtunpass).each do |key_name|
        cert = Base64.encode64(::File.new("#{cluster_keys_dir}/#{key_name}").read)
        node.set['eucalyptus']['cloud-keys'][cluster][key_name] = cert
        node.save
      end
    end
    not_if "#{Chef::Config[:solo]}"
  end
  ruby_block "Upload cluster keys Chef Server" do
    block do
      %w(cloud-cert.pem cluster-cert.pem cluster-pk.pem node-cert.pem node-pk.pem vtunpass).each do |key_name|
        cert = Base64.encode64(::File.new("#{cluster_keys_dir}/#{key_name}").read)
        node.default['eucalyptus']['cloud-keys'][cluster][key_name] = cert
        node.save
      end
    end
    not_if "#{Chef::Config[:solo]}"
  end
  ### In solo mode (ie faststart) ensure that we copy the cluster keys over for the CC
  execute "Copy keys locally" do
    command "cp #{cluster_keys_dir}/* #{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/"
    only_if "#{Chef::Config[:solo]}"
  end
end

### If this is 4.x we need to register User facing services
if node['eucalyptus']['topology']['user-facing']
      user_facing = node['eucalyptus']['topology']['user-facing']
  else
      user_facing = [ node['ipaddress'] ]
end
user_facing.each do |uf_ip|
  execute "Register User Facing #{uf_ip}" do
    command "#{euca_conf}  --register-service -T user-api -H #{uf_ip} -N API_#{uf_ip} #{dont_sync_keys}"
    not_if "egrep '3.[0-9].[0-9]' #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version || #{disable_proxy} euca-describe-services | egrep 'API_#{uf_ip}'"
  end
end

if node['eucalyptus']['topology']['walrus']
  execute "Register Walrus" do
    command "#{euca_conf} --register-walrus -P walrus -H #{node['eucalyptus']['topology']['walrus']} -C walrus-1 #{dont_sync_keys}"
    not_if "#{disable_proxy} euca-describe-services | grep walrus-1"
  end
end
