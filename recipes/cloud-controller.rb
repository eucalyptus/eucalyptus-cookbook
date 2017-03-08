#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
#Copyright [2014] [Eucalyptus Systems]
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
## Install unzip so we can extract creds
yum_package "unzip" do
  action :upgrade
  options node['eucalyptus']['yum-options']
end

include_recipe "eucalyptus::cloud-service"

execute "Initialize Eucalyptus DB" do
 command "#{node["eucalyptus"]["home-directory"]}/usr/sbin/clcadmin-initialize-cloud"
 creates "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/db/data/server.crt"
end

if node["eucalyptus"]["network"]["mode"] == "VPCMIDO"
  include_recipe "eucalyptus::eucanetd"
  yum_package "nginx" do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
  execute "setsebool httpd_can_network_connect true" do
    command "/usr/sbin/setsebool -P httpd_can_network_connect 1"
  end
end

execute "Configure kernel parameters from 70-eucalyptus-cloud.conf" do
  command "/usr/lib/systemd/systemd-sysctl 70-eucalyptus-cloud.conf"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
