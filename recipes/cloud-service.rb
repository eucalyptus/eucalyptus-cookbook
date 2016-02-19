#
# Cookbook Name:: eucalyptus
# Recipe:: cloud-service
#
#© Copyright 2014-2016 Hewlett Packard Enterprise Development Company LP
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
#

# used for platform_version comparison
require 'chef/version_constraint'

include_recipe "eucalyptus::default"

source_directory = "#{node['eucalyptus']["home-directory"]}/source/#{node['eucalyptus']['source-branch']}"

## Install packages for the User Facing Services
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-cloud" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    notifies :create, "template[eucalyptus.conf]", :immediately
    flush_cache [:before]
  end
else
  include_recipe "eucalyptus::install-source"
  eucalyptus_dir = source_directory
  if node['eucalyptus']['source-repo'].end_with?("internal")
    eucalyptus_dir = "#{source_directory}/eucalyptus"
  end
  if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
    tools_dir = "#{eucalyptus_dir}/tools"
    execute "ln -sf #{tools_dir}/eucalyptus-cloud /etc/init.d/eucalyptus-cloud" do
      creates "/etc/init.d/eucalyptus-nc"
    end
    execute "chmod +x #{tools_dir}/eucalyptus-cloud"
  end
  if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
    file '/usr/lib/sysctl.d/70-eucalyptus-cloud.conf' do
      lazy { content IO.read("#{eucalyptus_dir}/systemd/sysctl.d/70-eucalyptus-cloud.conf") }
      mode '0644'
      action :create
      not_if do ::File.exists?('/usr/lib/sysctl.d/70-eucalyptus-cloud.conf') end
    end
    file '/usr/lib/systemd/system/eucalyptus-cloud.service' do
      lazy { content IO.read("#{eucalyptus_dir}/systemd/units/eucalyptus-cloud.service") }
      mode '0644'
      action :create
      not_if do ::File.exists?('/usr/lib/systemd/system/eucalyptus-cloud.service') end
    end
    file '/usr/lib/systemd/system/eucalyptus-cloud-upgrade.service' do
      lazy { content IO.read("#{eucalyptus_dir}/systemd/units/eucalyptus-cloud-upgrade.service") }
      mode '0644'
      action :create
      not_if do ::File.exists?('/usr/lib/systemd/system/eucalyptus-cloud-upgrade.service') end
    end
  end
end

yum_package "euca2ools" do
  action :upgrade
  options node['eucalyptus']['yum-options']
end

if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  if node["eucalyptus"]["bind-interface"]
    # Auto detect IP from interface name
    bind_addr = Eucalyptus::BindAddr.get_bind_interface_ip(node)
  else
    # Use default gw interface IP
    bind_addr = node["ipaddress"]
  end
  node.override['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + bind_addr
end

template "eucalyptus.conf" do
  path   "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  source "eucalyptus.conf.erb"
  action :create
end
