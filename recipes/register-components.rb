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
  command "/usr/sbin/clcadmin-assume-system-credentials | grep -q AWS_ACCESS_KEY_ID"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 15
  retry_delay 30
end

ruby_block "Upload cloud keys Chef Server" do
  block do
    Eucalyptus::KeySync.upload_cloud_keys(node)
  end
end

##### Register clusters
clusters = node["eucalyptus"]["topology"]["clusters"]
as_admin = "eval `clcadmin-assume-system-credentials` && "
command_prefix = "#{as_admin} #{node['eucalyptus']['home-directory']}"
register_service = "#{command_prefix}/usr/bin/euserv-register-service"
describe_services = "#{command_prefix}/usr/bin/euserv-describe-services"


clusters.each do |cluster, info|
  if info["cc"] == ""
    cc_ips = node['ipaddress']
  else
    cc_ips = info["cc"]
  end

  cc_ips.each_with_index do |cc_ip, index|
    execute "Register CC" do
      command "#{register_service} -t cluster -z #{cluster} -h #{cc_ip} #{cluster}-cc-#{index}"
      not_if "#{describe_services} | grep #{cluster}-cc-#{index}"
      retries 15
      retry_delay 10
    end
  end
  if info["sc"] == ""
    sc_ips = node['ipaddress']
  else
    sc_ips = info["sc"]
  end

  sc_ips.each_with_index do |sc_ip, index|
    execute "Register SC" do
      command "#{register_service} -t storage -z #{cluster} -h #{sc_ip} #{cluster}-sc-#{index}"
      not_if "#{describe_services} | grep #{cluster}-sc-#{index}"
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
  end
  ruby_block "Upload cluster keys Chef Server" do
    block do
      %w(cloud-cert.pem cluster-cert.pem cluster-pk.pem node-cert.pem node-pk.pem vtunpass).each do |key_name|
        cert = Base64.encode64(::File.new("#{cluster_keys_dir}/#{key_name}").read)
        node.default['eucalyptus']['cloud-keys'][cluster][key_name] = cert
        node.save
      end
    end
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
    command "#{register_service} -t user-api -h #{uf_ip} API_#{uf_ip}"
    not_if "#{describe_services} | egrep 'API_#{uf_ip}'"
    retries 20
    retry_delay 10
  end
end

if node['eucalyptus']['topology']['objectstorage']['walrusbackend']
  walrusbackends = node['eucalyptus']['topology']['objectstorage']['walrusbackend']
  walrusbackends.each_with_index do |walrus, index|
    execute "Register Walrus" do
      command "#{register_service} -t walrusbackend -h #{walrus} walrus-#{index}"
      not_if "#{describe_services} | grep walrus"
    end
  end
end
