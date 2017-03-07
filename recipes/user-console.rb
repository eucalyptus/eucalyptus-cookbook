#
# Cookbook Name:: eucalyptus
# Recipe:: user-console
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
## Install packages for the user-console

# used for platform_version comparison
require 'chef/version_constraint'

include_recipe "eucalyptus::default"

if node['eucalyptus']['user-console']['install-type'] == 'sources'
  %w{openssl-devel python-devel swig gcc libmemcached1 python-pylibmc
     python-pyramid}.each do |package_name|
    yum_package package_name do
      options node['eucalyptus']['yum-options']
    end
  end
  source_branch = node['eucalyptus']['user-console']['source-branch']
  source_repo = node['eucalyptus']['user-console']['source-repo']
  source_directory = "#{node['eucalyptus']["home-directory"]}/source/eucaconsole"
  ### Checkout eucaconsole Source
  git source_directory do
    repository source_repo
    revision source_branch
    action :sync
  end
  execute "Install python dependencies" do
    command "python setup.py develop"
    cwd source_directory
  end
  execute "Copy config file into place" do
    command "cp conf/console.default.ini console.ini"
    cwd source_directory
  end
  ### Setup eucaconsole service
  ### Checkout eucaconsole packaging code
  packaging_directory = "#{node['eucalyptus']["home-directory"]}/source/eucaconsole-rpmspec"
  git packaging_directory do
    repository node['eucalyptus']['user-console']['packaging-repo']
    revision node['eucalyptus']['user-console']['packaging-branch']
    action :sync
  end
  user "eucaconsole"
  config_directory = "/etc/eucaconsole"
  run_directory = "/var/run/eucaconsole"
  eucaconsole_user = 'eucaconsole'
  [config_directory, run_directory].each do |eucaconsole_dir|
    directory eucaconsole_dir do
      owner eucaconsole_user
      group eucaconsole_user
      action :create
    end
  end
  file "/var/log/eucaconsole.log" do
    owner eucaconsole_user
    group eucaconsole_user
    mode "0755"
    action :create
  end
  execute "chmod +x #{packaging_directory}/eucaconsole"
  execute "ln -sf #{source_directory}/console.ini #{config_directory}/console.ini"
  execute "ln -sf #{packaging_directory}/eucaconsole /usr/bin/eucaconsole"
  execute "ln -sf #{packaging_directory}/eucaconsole.init /etc/init.d/eucaconsole"
else
  yum_package "eucaconsole" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    flush_cache [:before]
  end
end

if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  execute "setsebool httpd_can_network_connect true" do
    command "/usr/sbin/setsebool -P httpd_can_network_connect 1"
  end
end

service "eucaconsole" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
