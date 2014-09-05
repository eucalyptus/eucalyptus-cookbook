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
include_recipe "eucalyptus::default"

if node['eucalyptus']['user-console']['install-type'] == 'source'
  %w{openssl-devel python-devel swig gcc}.each do |package_name|
    package package_name
  end
  source_branch = node['eucalyptus']['user-console']['source-branch']
  source_repo = node['eucalyptus']['user-console']['source-repo']
  source_directory = "#{node['eucalyptus']["home-directory"]}/source/eucaconsole"
  ### Checkout eucaconsole Source
  git source_directory do
    repository source_repo
    revision source_branch
    checkout_branch source_branch
    action :sync
  end
  execute "Install python dependencies" do
    command "python setup.py develop"
    cwd source_directory = node['eucalyptus']['home-directory'] + "/eucaconsole"
  end
  execute "Copy config file into place" do
    command "cp conf/console.default.ini console.ini"
     cwd source_directory = node['eucalyptus']['home-directory'] + "/eucaconsole"
  end
  execute "Run eucaconsole in background" do
    command "./launcher &"
     cwd source_directory = node['eucalyptus']['home-directory'] + "/eucaconsole"
  end
else
  yum_package "eucaconsole" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    flush_cache [:before]
  end

  service "eucaconsole" do
    action [ :enable, :start ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end
