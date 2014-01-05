#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install binaries for the CC
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-cc" do
    action :install
    options node['eucalyptus']['yum-options']
  end
else
  ## Install CC from source from internal repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus/"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/eucalyptus/cluster"
    creates "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus/cluster/generated"
  end
  ## Install CLC from open source repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/cluster"
    creates "#{node["eucalyptus"]["home-directory"]}/source/cluster/generated"
  end
  ### Create symlink for eucalyptus-cloud service
  tools_dir = "#{node["eucalyptus"]["home-directory"]}/source/tools"
  if node['eucalyptus']['source-repo'].end_with?("internal")
    tools_dir = "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus/tools"
  end

  execute "ln -s #{tools_dir}/eucalyptus-cc /etc/init.d/eucalyptus-cc" do
    creates "/etc/init.d/eucalyptus-cc"
  end

  execute "chmod +x #{tools_dir}/eucalyptus-cc"
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
end

execute "export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --setup"

service "eucalyptus-cc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
