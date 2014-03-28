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
  retries 10
  retry_delay 50
end

##### Register clusters
clusters = node["eucalyptus"]["topology"]["clusters"]
command_prefix = "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && #{node['eucalyptus']['home-directory']}"
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
    not_if "euca-describe-services | grep #{cluster}-cc-1"
  end
  if info["sc-1"] == ""
	sc_ip = node['ipaddress']
  else
	sc_ip = info["sc-1"]
  end
  
  execute "Register SC" do
    command "#{euca_conf} --register-sc -P #{cluster} -H #{sc_ip} -C #{cluster}-sc-1 #{dont_sync_keys}"
    not_if "euca-describe-services | grep #{cluster}-sc-1"
  end
  #### Sync cluster keys
  cluster_keys_dir = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{cluster}"
  ruby_block "Upload cloud keys Chef Server" do
    block do
      %w(cloud-cert.pem cluster-cert.pem cluster-pk.pem node-cert.pem node-pk.pem vtunpass).each do |key_name|
        cert = Base64.encode64(::File.new("#{cluster_keys_dir}/#{key_name}").read)
        node.set['eucalyptus']['cloud-keys'][cluster][key_name] = cert
        node.save
      end
    end
    not_if "#{Chef::Config[:solo]}"
  end
  execute "Copy keys locally" do
    command "cp #{cluster_keys_dir}/* #{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/"
    only_if "#{Chef::Config[:solo]}"
  end
end

if node['eucalyptus']['topology']['osg'] == ""
      osg_ip = node['ipaddress']
  else
      osg_ip = node['eucalyptus']['topology']['osg']
end
### If this is 4.0 we need to register an OSG

execute "Register OSG" do
  command "#{euca_conf} --register-osg -P osg -H #{osg_ip} -C osg-1 #{dont_sync_keys}"
  not_if "euca-describe-services | grep osg-1"
  only_if "grep 4.0 #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
end

if node['eucalyptus']['network']['mode'] == "EDGE"
  file "#{node['eucalyptus']['admin-cred-dir']}/network.json" do
    content node['eucalyptus']['network']['config-json'].to_json
    mode "644"
    action :create
  end
  execute "Configure network" do
    command "#{modify_property} -f cloud.network.network_configuration=#{node['eucalyptus']['admin-cred-dir']}/network.json"
  end
end

if node['eucalyptus']['topology']['riak']['endpoint'] != ""
  ### Setup for riak integration
  execute "#{modify_property} -p objectstorage.providerclient=s3"
  execute "#{modify_property} -p objectstorage.s3provider.s3endpoint=#{node['eucalyptus']['topology']['riak']['endpoint']}"
  execute "#{modify_property} -p objectstorage.s3provider.s3accesskey=#{node['eucalyptus']['topology']['riak']['access-key']}"
  execute "#{modify_property} -p objectstorage.s3provider.s3secretkey=#{node['eucalyptus']['topology']['riak']['secret-key']}"
else
  ### Use legacy walrus

  ### In 4.0 need to setup OSG to point to Walrus
  execute "Set OSG providerclient" do
    command "#{modify_property} -p objectstorage.providerclient=walrus"
    only_if "grep 4.0 #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
  end

  ### Get correct walrus IP
  if node['eucalyptus']['topology']['walrus'] == ""
      walrus_ip = node['ipaddress']
  else
      walrus_ip = node['eucalyptus']['topology']['walrus']
  end

  ##### Register Walrus
  execute "Register Walrus" do
    command "#{euca_conf} --register-walrusbackend -P walrus -H #{walrus_ip} -C walrus-1 #{dont_sync_keys}"
    not_if "euca-describe-services | grep walrus-1"
  end
end

execute "Wait for credentials with S3 URL populated" do
  command "rm -rf admin.zip && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --get-credentials admin.zip && unzip -o admin.zip && grep 'export S3_URL' eucarc"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 10
  retry_delay 50
  not_if "grep 'export S3_URL' #{node['eucalyptus']['admin-cred-dir']}/eucarc"
end

### Register ELB Image
if node['eucalyptus']['install-load-balancer']
  if node['eucalyptus']['load-balancer-repo'] != ""
    yum_repository "eucalyptus-load-balancer" do
      description "Eucalyptus LoadBalancer Repo"
      url node["eucalyptus"]["load-balancer-repo"]
      gpgcheck false
    end
  end
  yum_package "eucalyptus-load-balancer-image" do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
  execute "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && export EUCALYPTUS=#{node["eucalyptus"]["home-directory"]} && euca-install-load-balancer --install-default" do
    only_if "#{describe_property} loadbalancing.loadbalancer_emi | grep '{}'" 
  end
end

### Register Imaging Service Image
if node['eucalyptus']['install-imaging-worker']
  if node['eucalyptus']['imaging-worker-repo'] != ""
    yum_repository "eucalyptus-imaging-worker" do
      description "Eucalyptus Imaging Repo"
      url node["eucalyptus"]["imaging-worker-repo"]
      gpgcheck false
    end
  end
  yum_package "eucalyptus-imaging-worker-image" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    only_if "grep 4.0 #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
  end
  execute "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && export EUCALYPTUS=#{node["eucalyptus"]["home-directory"]} && euca-install-imaging-worker --install-default" do
    only_if "#{describe_property} imaging.imaging_worker_emi | grep '{}'"
  end
end

execute "Set DNS server on CLC" do
  command "#{modify_property} -p system.dns.nameserveraddress=#{node["eucalyptus"]["network"]["dns-server"]}"
end
