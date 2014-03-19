#
# Cookbook Name:: eucalyptus
# Recipe:: eucalyptus-console
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

yum_repository "eucalyptus-console" do
   description "Eucalyptus Console Repo"
   url node["eucalyptus"]["user-console-repo"]
   only_if { node['eucalyptus']['user-console-repo'] != '' }
end

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-console" do
    action :install
    options node['eucalyptus']['yum-options']
  end
#else
  ## Source install stuff here
end

service "eucalyptus-console" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
