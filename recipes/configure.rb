#
# Cookbook Name:: eucalyptus
# Recipe:: configure
#
#Copyright [2014-2015] [Eucalyptus Systems]
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
disable_proxy = 'http_proxy=""'
as_admin = "export AWS_DEFAULT_REGION=localhost; eval `clcadmin-assume-system-credentials` && "
command_prefix = "#{as_admin} #{node['eucalyptus']['home-directory']}"
describe_services = "#{command_prefix}/usr/bin/euserv-describe-services"
euctl = "#{command_prefix}/usr/bin/euctl"

if node['eucalyptus']['dns']['domain']
  execute "Enable DNS delegation" do
    command "#{euctl} bootstrap.webservices.use_dns_delegation=true"
    retries 15
    retry_delay 20
  end
  execute "Set DNS domain to #{node['eucalyptus']['dns']['domain']}" do
    command "#{euctl} system.dns.dnsdomain=#{node['eucalyptus']['dns']['domain']}"
    retries 15
    retry_delay 20
  end
  execute "Enable instance DNS" do
    command "#{euctl} bootstrap.webservices.use_instance_dns=true"
    retries 15
    retry_delay 20
  end
end

if node['riakcs_cluster']
  admin_key, admin_secret = RiakCSHelper::CreateUser.download_riak_credentials(node)
  Chef::Log.info "Existing RiakCS admin_key: #{admin_key}"
  Chef::Log.info "Existing RiakCS admin_secret: #{admin_secret}"
  execute "Set-objectstorage.providerclient-to-riakcs" do
    command "#{euctl} objectstorage.providerclient=riakcs"
    retries 15
    retry_delay 20
  end

  if node['riakcs_cluster']['topology']['load_balancer']
    if node['haproxy']['incoming_port']
      s3_endpoint = "#{node['riakcs_cluster']['topology']['load_balancer']}:#{node['haproxy']['incoming_port']}"
    else
      s3_endpoint = "#{node['riakcs_cluster']['topology']['load_balancer']}:80"
    end
  else
    s3_endpoint = "#{node['riakcs_cluster']['topology']['head']['ipaddr']}:8080"
  end

  execute "Set S3 endpoint" do
    command "#{euctl} objectstorage.s3provider.s3endpoint=#{s3_endpoint}"
    retries 15
    retry_delay 20
  end
  execute "Set providerclient access-key" do
    command "#{euctl} objectstorage.s3provider.s3accesskey=#{admin_key}"
    retries 5
    retry_delay 20
  end
  execute "Set providerclient secret-key" do
    command "#{euctl} objectstorage.s3provider.s3secretkey=#{admin_secret}"
    retries 5
    retry_delay 20
  end
elsif node['eucalyptus']['topology']['riakcs']
  execute "Set OSG providerclient to riakcs" do
    command "#{euctl} objectstorage.providerclient=riakcs"
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
    Chef::Log.info "RiakCS admin_key: #{admin_key}"
    Chef::Log.info "RiakCS admin_secret: #{admin_secret}"
  end

  execute "Set S3 endpoint" do
    command "#{euctl} objectstorage.s3provider.s3endpoint=#{node['eucalyptus']['topology']['riakcs']['endpoint']}"
    retries 15
    retry_delay 20
  end
  execute "#{euctl} objectstorage.s3provider.s3accesskey=#{admin_key}"
  execute "#{euctl} objectstorage.s3provider.s3secretkey=#{admin_secret}"
else
  execute "Set OSG providerclient" do
    # for the short term due to errors in CI, run with --debug
    command "#{euctl} --debug objectstorage.providerclient=walrus"
    only_if "egrep '4.[0-9].[0-9]' #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
    retries 15
    retry_delay 20
    subscribes :start, "service[ufs-eucalyptus-cloud]", :immediately
  end
end

if Eucalyptus::Enterprise.is_enterprise?(node)
  if Eucalyptus::Enterprise.is_san?(node)
    node['eucalyptus']['topology']['clusters'].each do |cluster, info|
      case info['storage-backend']
      when 'emc-vnx'
        san_package = 'eucalyptus-enterprise-storage-san-emc-libs'
      when 'netapp'
        san_package = 'eucalyptus-enterprise-storage-san-netapp-libs'
      when 'equallogic'
        san_package = 'eucalyptus-enterprise-storage-san-equallogic-libs'
      when 'threepar'
        san_package = 'eucalyptus-enterprise-storage-san-threepar-libs'
      else
        # This cluster is not SAN backed
        san_package = nil
      end
      if san_package and node["eucalyptus"]["install-type"] == "packages"
        yum_package san_package do
          action :upgrade
          options node['eucalyptus']['yum-options']
          notifies :restart, "service[eucalyptus-cloud]", :immediately
          flush_cache [:before]
        end
      end
    end
  end
end

%w{objectstorage compute cloudformation}.each do |service|
  execute "Wait for enabled #{service}" do
    command "#{describe_services} --filter service-type=#{service} | grep enabled"
    retries 15
    retry_delay 20
  end
end

execute "Set DNS server on CLC" do
  command "#{euctl} system.dns.nameserveraddress=#{node["eucalyptus"]["network"]["dns-server"]}"
end

file "#{node['eucalyptus']['admin-cred-dir']}/network.json" do
  content JSON.pretty_generate(node['eucalyptus']['network']['config-json'], quirks_mode: true)
  mode '644'
  action :create
end
execute "Configure network" do
  command "#{euctl} cloud.network.network_configuration=@#{node['eucalyptus']['admin-cred-dir']}/network.json"
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
     command "#{euctl} #{cluster}.storage.blockstoragemanager=#{storage_backend} | grep #{storage_backend}"
     ### Patch for EUCA-9963
     not_if "#{euctl} #{cluster}.storage.blockstoragemanager | grep #{storage_backend}"
     retries 15
     retry_delay 20
  end
  ### Configure backend
  case info["storage-backend"]
  when "das"
    execute "Set das device" do
      # for the short term due to errors in CI, run with --debug
      command "#{euctl} --debug #{cluster}.storage.dasdevice=#{info["das-device"]} | grep #{info["das-device"]}"
      retries 15
      retry_delay 20
    end
  end
end

### Register Service Image
if node['eucalyptus']['install-service-image']
  if node['eucalyptus']['service-image-repo'] != ""
    yum_repository "eucalyptus-service-image" do
      description "Eucalyptus Service Image Repo"
      url node["eucalyptus"]["service-image-repo"]
      gpgcheck false
    end
  end
  yum_package "eucalyptus-service-image" do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
  if node['eucalyptus']['imaging-vm-type']
    execute "Set imaging VM instance type" do
      command "#{euctl} services.imaging.worker.instance_type=#{node['eucalyptus']['imaging-vm-type']}"
      retries 15
      retry_delay 20
    end
  end
  if node['eucalyptus']['loadbalancing-vm-type']
    execute "Set loadbalancing VM instance type" do
      command "#{euctl} services.loadbalancing.worker.instance_type=#{node['eucalyptus']['loadbalancing-vm-type']}"
      retries 15
      retry_delay 20
    end
  end
  execute "#{as_admin} S3_URL=http://s3.#{node["eucalyptus"]["dns"]["domain"]}:8773/ esi-install-image --region localhost --install-default" do
    retries 5
    retry_delay 20
    only_if "#{euctl} services.imaging.worker.image | grep 'NULL'"
  end
  execute "#{as_admin} esi-manage-stack --region localhost -a create imaging" do
    only_if "#{euctl} services.imaging.worker.configured | grep 'false'"
  end
end

node['eucalyptus']['system-properties'].each do |key, value|
  execute "#{euctl} #{key}=\"#{value}\"" do
    retries 10
    retry_delay 5
    not_if "#{euctl} #{key} | grep \"#{value}\""
  end
end

if node['eucalyptus']['network']['mode'] == 'VPCMIDO'
  execute 'Create default VPC for eucalyptus account' do
    command "#{as_admin} euca-create-vpc `euare-accountlist | grep '^eucalyptus' | awk '{print $2}'`"
    not_if "#{as_admin} euca-describe-vpcs | grep 'VPC.*default.*true'"
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
