#
# Cookbook Name:: eucalyptus
# Recipe:: user-facing
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

include_recipe "eucalyptus::cloud-service"

ruby_block "Get keys from CLC" do
  block do
    if node["eucalyptus"]["topology"]["clc-1"] != ""
      clc_ip = node["eucalyptus"]["topology"]["clc-1"]
      clc  = search(:node, "addresses:#{clc_ip}").first
      node.set["eucalyptus"]["cloud-keys"] = clc["eucalyptus"]["cloud-keys"]
      node.set["eucalyptus"]["cloud-keys"]["euca.p12"] = clc["eucalyptus"]["cloud-keys"]["euca.p12"]
      node.save
      node["eucalyptus"]["cloud-keys"].each do |key_name,data|
        if data.is_a? String
          file_name = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{key_name}"
          File.open(file_name, 'w') do |file|
            file.puts Base64.decode64(data)
          end
          require 'fileutils'
          FileUtils.chmod 0700, file_name
          FileUtils.chown 'eucalyptus', 'eucalyptus', file_name
        end
     end
    end
  end
  not_if "#{Chef::Config[:solo]}"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
