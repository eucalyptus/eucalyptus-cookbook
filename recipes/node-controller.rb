#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install packages for the NC

include_recipe "bridger"

node[:bridger][:interface] = node["eucalyptus"]["network"]["public-interface"] # (interface to bridge to)
node[:bridger][:name] = node["eucalyptus"]["network"]["bridge-interface"] # (name of the bridge)
### Need to add these to config
node[:bridger][:dhcp] = 'true' # (dhcp in use on interface)
#node[:bridger][:address] = nil # (static address to use)
#node[:bridger][:netmask] = '255.255.255.0' # (netmask in use)
#node[:bridger][:gateway] = nil # (gateway to use)

if node["eucalyptus"]["install-type"] == "packages"
  package "eucalyptus-nc" do
    action :install
  end
else
  ## Install CC from source from internal repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus/node"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/eucalyptus/node"
  end
  ## Install CLC from open source repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/node"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/node"
  end
  ### Create symlink for eucalyptus-cloud service
  execute "ln -s #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-nc /etc/init.d/eucalyptus-nc"
  execute "chmod +x #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-nc"
  execute "chown -R eucalyptus:eucalyptus #{node["eucalyptus"]["home-directory"]}"
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  mode 0440
  owner "eucalyptus"
  group "eucalyptus"
end

service "eucalyptus-nc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
