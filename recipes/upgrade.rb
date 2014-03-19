#
# Cookbook Name:: eucalyptus
# Recipe:: upgrade
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

## Stop all euca components
service "eucalyptus-nc" do
  action [ :stop ]
end

service "eucalyptus-cc" do
  action [ :stop ]
end

service "eucalyptus-cloud" do
  action [ :stop ]
end

if node["eucalyptus"]["install-type"] == "packages"

  ## remove previous repo
  yum_repository "eucalyptus-release" do
   action :delete
  end

  yum_repository "euca2ools-release" do
    action :delete
  end

  ## Clean yum cache
  execute 'upgrade euca2ools package' do
    command 'yum clean expire-cache'
  end

  ## update repo URLs
  ## http://packages.release.eucalyptus-systems.com/yum/builds/eucalyptus/branch/maint-3.4-testing/centos/6/x86_64/
  yum_repository "eucalyptus-release" do
    description "Eucalyptus Package Repo"
    url node["eucalyptus"]["eucalyptus-repo"]
    gpgcheck false
    action :create
  end

  ##
  yum_repository "euca2ools-release" do
    description "Euca2ools Package Repo"
    url node["eucalyptus"]["euca2ools-repo"]
    gpgcheck false
    action :create
  end

  ## Upgrade euca packages chef yum_package does not seem to like wildcard
  execute 'upgrade euca packages' do
    command "yum -y update 'eucalyptus*'"
  end

  ## Upgrade euca2ools
  execute 'upgrade euca2ools package' do
    command 'yum -y update euca2ools'
  end
end

if node['eucalyptus']['install-type'] == 'source'
  ### Checkout Eucalyptus Source
  execute 'Checkout source' do
    cwd node['eucalyptus']['home-directory']
    command "git pull -uv #{node['eucalyptus']['source-repo']} -b #{node['eucalyptus']['source-branch']} source"
  end

  execute 'Init submodules' do
    cwd "#{node['eucalyptus']['home-directory']}/source"
    command 'git submodule init && git submodule update'
  end

  yum_repository 'euca-vmware-libs' do
    description 'VDDK libs repo'
    url node['eucalyptus']['vddk-libs-repo']
    action :upgrade
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/vmware-broker"
  end
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

service "eucalyptus-cc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

service "eucalyptus-nc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
