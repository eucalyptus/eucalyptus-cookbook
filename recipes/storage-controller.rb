#
# Cookbook Name:: eucalyptus
# Recipe:: default
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

include_recipe "eucalyptus::default"

node["eucalyptus"]["topology"]["clusters"].each do |name, info|
  log "Found Cluster" do
    message "Found cluster #{name} with attributes: #{info}"
    level :info
  end
  addresses = []
  node["network"]["interfaces"].each do |interface, info|
    info["addresses"].each do |address, info|
      addresses.push(address)
    end
  end
  if addresses.include?(info["cc-1"]) and not Chef::Config[:solo]
    node.set["eucalyptus"]["local-cluster-name"] = name
    node.save
  elsif Chef::Config[:solo]
    log "Using cluster name: " + node["eucalyptus"]["local-cluster-name"]  
  else
    raise "Unable to find cluster controller for cluster: " + name
  end
end

### Set bind-addr if necessary
if node["eucalyptus"]["set-bind-addr"] and not node["eucalyptus"]["cloud-opts"].include?("bind-addr")
  node.set['eucalyptus']['cloud-opts'] = node['eucalyptus']['cloud-opts'] + " --bind-addr=" + node["eucalyptus"]["topology"]['clusters'][node["eucalyptus"]["local-cluster-name"]]["sc-1"]
  node.save
end

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-sc" do
    action :upgrade
    options node['eucalyptus']['yum-options']
    notifies :create, "template[eucalyptus.conf]"
    notifies :restart, "service[eucalyptus-cloud]", :immediately
    flush_cache [:before]
  end
else
  ## Install CC from source from internal repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["source-directory"]}/eucalyptus"
    only_if "ls #{node["eucalyptus"]["source-directory"]}/eucalyptus/clc"
    creates "/etc/init.d/eucalyptus-cloud"
    timeout node["eucalyptus"]["compile-timeout"]
  end
  ## Install CLC from open source repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["source-directory"]}"
    only_if "ls #{node["eucalyptus"]["source-directory"]}/clc"
    creates "/etc/init.d/eucalyptus-cloud"
    timeout node["eucalyptus"]["compile-timeout"]
  end
  ### Create symlink for eucalyptus-cloud service
  tools_dir = "#{node["eucalyptus"]["source-directory"]}/tools"
  if node['eucalyptus']['source-repo'].end_with?("internal")
    tools_dir = "#{node["eucalyptus"]["source-directory"]}/eucalyptus/tools"
  end

  execute "ln -s #{tools_dir}/eucalyptus-cloud /etc/init.d/eucalyptus-cloud" do
    creates "/etc/init.d/eucalyptus-cloud"
  end

  execute "chmod +x #{tools_dir}/eucalyptus-cloud"
end

template "eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  path "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf"
  action :create
end

execute "export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --setup"


ruby_block "Get cluster keys from CLC" do
  block do
    if node["eucalyptus"]["topology"]["clc-1"] != ""
      clc_ip = node["eucalyptus"]["topology"]["clc-1"]
      clc  = search(:node, "addresses:#{clc_ip}").first
      node.set["eucalyptus"]["cloud-keys"][node["eucalyptus"]["local-cluster-name"]] = clc["eucalyptus"]["cloud-keys"][node["eucalyptus"]["local-cluster-name"]]
      node.set["eucalyptus"]["cloud-keys"]["euca.p12"] = clc["eucalyptus"]["cloud-keys"]["euca.p12"]
      node.save
    else
      node.set["eucalyptus"]["cloud-keys"][node["eucalyptus"]["local-cluster-name"]] = node["eucalyptus"]["cloud-keys"][node["eucalyptus"]["local-cluster-name"]]
      node.save
    end
    node["eucalyptus"]["cloud-keys"][node["eucalyptus"]["local-cluster-name"]].each do |key_name,data|
     file_name = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{key_name}"
     File.open(file_name, 'w') do |file|
       file.puts Base64.decode64(data)
     end
     require 'fileutils'
     FileUtils.chmod 0700, file_name
     FileUtils.chown 'eucalyptus', 'eucalyptus', file_name
    end
    euca_p12 = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/euca.p12"
    File.open(euca_p12, 'w') do |file|
       file.puts Base64.decode64(node["eucalyptus"]["cloud-keys"]["euca.p12"])
    end
  end
  not_if "#{Chef::Config[:solo]}"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
