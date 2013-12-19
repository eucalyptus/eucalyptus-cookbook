#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Setup Bridge
template "/etc/sysconfig/network-scripts/ifcfg-" + node["eucalyptus"]["network"]["bridged-nic"] do
  source "ifcfg-eth0.erb"
  mode 0440
  owner "root"
  group "root"
end

template "/etc/sysconfig/network-scripts/ifcfg-" + node["eucalyptus"]["network"]["bridge-interface"] do
  source "ifcfg-br0.erb"
  mode 0440
  owner "root"
  group "root"
end

execute "service network restart"

## Install packages for the NC
if node["eucalyptus"]["install-type"] == "packages"
  package "eucalyptus-nc" do
    action :install
  end
else
  ## Install CC from source from internal repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/eucalyptus"
    creates "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus/node/generated"
  end
  ## Install CLC from open source repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source"
    creates "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus/node/generated"
  end
  ### Create symlink for eucalyptus-cloud service
  execute "ln -s #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-nc /etc/init.d/eucalyptus-nc"
  execute "cp #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-nc-libvirt.pkla /var/lib/polkit-1/localauthority/10-vendor.d/eucalyptus-nc-libvirt.pkla"
  execute "chmod +x #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-nc"
  service "messagebus" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
  end
end

## Setup bridge to allow instances to dhcp properly and early on
execute "brctl setfd #{node["eucalyptus"]["network"]["bridge-interface"]} 2"
execute "brctl sethello #{node["eucalyptus"]["network"]["bridge-interface"]} 2"
execute "brctl stp #{node["eucalyptus"]["network"]["bridge-interface"]} off"

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
end

execute "export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --setup"

service "eucalyptus-nc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
