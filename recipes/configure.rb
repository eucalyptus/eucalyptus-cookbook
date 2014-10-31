#
# Cookbook Name:: eucalyptus
# Recipe:: configure
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
command_prefix = "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && #{node['eucalyptus']['home-directory']}"
modify_property = "#{command_prefix}/usr/sbin/euca-modify-property"
describe_services = "#{command_prefix}/usr/sbin/euca-describe-services"
describe_property = "#{command_prefix}/usr/sbin/euca-describe-properties"
if node['eucalyptus']['topology']['riakcs']
  execute "Set OSG providerclient to riakcs" do
    command "#{modify_property} -p objectstorage.providerclient=riakcs"
    retries 15
    retry_delay 20
  end

  admin_key = node['eucalyptus']['topology']['riakcs']['access-key']
  admin_secret = node['eucalyptus']['topology']['riakcs']['secret-key']

  if admin_key == ""
    admin_key, admin_secret = RiakCSHelper::CreateUser.create_riakcs_user(
         node["eucalyptus"]["topology"]["riakcs"]["admin-name"],
         node["eucalyptus"]["topology"]["riakcs"]["admin-email"],
         node["eucalyptus"]["topology"]["riakcs"]["endpoint"],
         node["eucalyptus"]["topology"]["riakcs"]["port"],
    )
    Chef::Log.info "shaon: admin_key: #{admin_key}"
    Chef::Log.info "shaon: admin_secret: #{admin_secret}"
  end

  execute "Set S3 endpoint" do
    command "#{modify_property} -p objectstorage.s3provider.s3endpoint=#{node['eucalyptus']['topology']['riakcs']['endpoint']}"
    retries 15
    retry_delay 20
  end
  execute "#{modify_property} -p objectstorage.s3provider.s3accesskey=#{admin_key}"
  execute "#{modify_property} -p objectstorage.s3provider.s3secretkey=#{admin_secret}"
else
  execute "Set OSG providerclient" do
    command "#{modify_property} -p objectstorage.providerclient=walrus"
    only_if "egrep '4.[0-9].[0-9]' #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
    retries 15
    retry_delay 20
  end
end

if Eucalyptus::Enterprise.is_enterprise?(node)
  if Eucalyptus::Enterprise.is_san?(node)
    node['eucalyptus']['topology']['clusters'].each do |cluster, info|
      case info['storage-backend']
      when 'emc-vnx'
        san_package = 'eucalyptus-enterprise-storage-san-emc-libs'
        execute "#{modify_property} -p #{cluster}.storage.clipath=#{node["eucalyptus"]["storage"]["emc"]["navicli-path"]}"
        execute "#{modify_property} -p #{cluster}.storage.storagepool=#{node["eucalyptus"]["storage"]["emc"]["storagepool"]}"
      when 'netapp'
        san_package = 'eucalyptus-enterprise-storage-san-netapp-libs'
      when 'equallogic'
        san_package = 'eucalyptus-enterprise-storage-san-equallogic-libs'
      end
      yum_package san_package do
        action :upgrade
        options node['eucalyptus']['yum-options']
        notifies :restart, "service[eucalyptus-cloud]", :immediately
        flush_cache [:before]
      end
    end
  end
end

execute "Wait for credentials with S3 URL populated" do
  command "rm -rf admin.zip && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --get-credentials admin.zip && unzip -o admin.zip && grep 'export S3_URL' eucarc"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 15
  retry_delay 20
  not_if "grep 'export S3_URL' #{node['eucalyptus']['admin-cred-dir']}/eucarc"
end

execute "Wait for credentials with EC2 URL populated" do
  command "rm -rf admin.zip && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --get-credentials admin.zip && unzip -o admin.zip && grep 'export EC2_URL' eucarc"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 15
  retry_delay 20
  not_if "grep 'export EC2_URL' #{node['eucalyptus']['admin-cred-dir']}/eucarc"
end

execute "Set DNS server on CLC" do
  command "#{modify_property} -p system.dns.nameserveraddress=#{node["eucalyptus"]["network"]["dns-server"]}"
end

if %w(EDGE VPCMIDO).include? node['eucalyptus']['network']['mode']
  file "#{node['eucalyptus']['admin-cred-dir']}/network.json" do
    content JSON.pretty_generate(node['eucalyptus']['network']['config-json'], quirks_mode: true)
    mode '644'
    action :create
  end
  execute "Configure network" do
    command "#{modify_property} -f cloud.network.network_configuration=#{node['eucalyptus']['admin-cred-dir']}/network.json"
  end
end

clusters = node["eucalyptus"]["topology"]["clusters"]
clusters.each do |cluster, info|
  ### Set backend
  storage_backend = "overlay"
  if info["storage-backend"]
    storage_backend = info["storage-backend"]
  else

  end
  execute "Set storage backend" do
     command "#{modify_property} -p #{cluster}.storage.blockstoragemanager=#{storage_backend} | grep #{storage_backend}"
     ### Patch for EUCA-9963
     not_if "#{describe_property} #{cluster}.storage.blockstoragemanager | grep #{storage_backend}"
     retries 15
     retry_delay 20
  end
  ### Configure backend
  case info["storage-backend"]
  when "das"
    execute "Set das device" do
      command "#{modify_property} -p #{cluster}.storage.dasdevice=#{info["das-device"]} | grep #{info["das-device"]}"
      retries 15
      retry_delay 20
    end
  end
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
    only_if "#{describe_property} loadbalancing.loadbalancer_emi | grep 'NULL'"
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
    only_if "egrep '4.[0-9].[0-9]' #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
  end
  execute "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && export EUCALYPTUS=#{node["eucalyptus"]["home-directory"]} && euca-install-imaging-worker --install-default" do
    only_if "#{describe_property} imaging.imaging_worker_emi | grep 'NULL'"
  end
end

node['eucalyptus']['system-properties'].each do |key, value|
  execute "#{modify_property} -p #{key}=\"#{value}\"" do
    retries 10
    retry_delay 5
    not_if "#{describe_property} #{key} | grep \"#{value}\""
  end
end

## Post script
if node['eucalyptus']['post-script-url'] != ""
  remote_file "#{node['eucalyptus']['home-directory']}/post.sh" do
    source node['eucalyptus']['post-script-url']
    mode "777"
  end
  execute 'Running post script' do
    command "bash #{node['eucalyptus']['home-directory']}/post.sh"
  end
end
