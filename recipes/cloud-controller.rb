#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install unzip so we can extract creds
yum_package "unzip" do
  action :install
  options node['eucalyptus']['yum-options']
end

## Install binaries for the CLC
if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-cloud" do
    action :install
    options node['eucalyptus']['yum-options']
  end
else
  execute "echo \"export PATH=$PATH:#{node['eucalyptus']['home-directory']}/usr/sbin/\" >>/root/.bashrc"
  ## Install CLC from source from internal repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["source-directory"]}/eucalyptus/"
    only_if "ls #{node["eucalyptus"]["source-directory"]}/eucalyptus/clc"
    creates "/etc/init.d/eucalyptus-cloud"
  end
  ## Install CLC from open source repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["source-directory"]}/"
    only_if "ls #{node["eucalyptus"]["source-directory"]}/clc"
    creates "/etc/init.d/eucalyptus-cloud"
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

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
end

execute "export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --setup"

execute "Stop any running cloud process" do
	command "service eucalyptus-cloud stop || true"
end

execute "Clear $EUCALYPTUS/var/run/eucalyptus" do
	command "rm -rf #{node["eucalyptus"]["home-directory"]}/var/run/eucalyptus/*"
end

execute "Initialize Eucalyptus DB" do
 command "#{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --initialize"
 creates "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/db/data/server.crt"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

execute "Wait for credentials." do
  command "rm -rf admin.zip && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --get-credentials admin.zip && unzip -o admin.zip"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 10
  retry_delay 50
end
