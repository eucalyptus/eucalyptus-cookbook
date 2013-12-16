#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

if node["eucalyptus"]["install-type"] == "packages"
  package "eucalyptus-sc" do
    action :install
  end
else
  ## Install CC from source from internal repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/eucalyptus/clc"
    creates "#{node["eucalyptus"]["home-directory"]}/usr/share/eucalyptus/eucalyptus-storage-*.jar"
  end
  ## Install CLC from open source repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/clc"
    creates "#{node["eucalyptus"]["home-directory"]}/usr/share/eucalyptus/eucalyptus-storage-*.jar"
  end
  ### Create symlink for eucalyptus-cloud service
  execute "ln -s #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-cloud /etc/init.d/eucalyptus-cloud"
  execute "chmod +x #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-cloud"
  execute "chown -R eucalyptus:eucalyptus #{node["eucalyptus"]["home-directory"]}"
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  mode 0440
  owner "eucalyptus"
  group "eucalyptus"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
