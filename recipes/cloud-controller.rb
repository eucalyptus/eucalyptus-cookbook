#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install unzip so we can extract creds
package "unzip" do
  action :install
end

## Install binaries for the CLC
if node["eucalyptus"]["install-type"] == "packages"
  package "eucalyptus-cloud" do
    action :install
  end
else
  # increasing max process limit to accommodate CLC
  execute 'echo "* soft nproc 64000" >>/etc/security/limits.conf'
  execute 'echo "* hard nproc 64000" >>/etc/security/limits.confi'
  execute 'rm /etc/security/limits.d/90-nproc.conf' # these apparently override limits.conf?
  execute "echo \"export PATH=$PATH:#{node['eucalyptus']['home-directory']}/usr/sbin/\" >>/root/.bashrc"
  ## Install CLC from source from internal repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/eucalyptus/"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/eucalyptus/clc"
    creates "#{node["eucalyptus"]["home-directory"]}/usr/share/eucalyptus/eucalyptus-cloud*.jar"
  end
  ## Install CLC from open source repo if it exists
  execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
    cwd "#{node["eucalyptus"]["home-directory"]}/source/"
    only_if "ls #{node["eucalyptus"]["home-directory"]}/source/clc"
    creates "#{node["eucalyptus"]["home-directory"]}/usr/share/eucalyptus/eucalyptus-cloud*.jar"
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

execute "Stop any running cloud process" do
	command "service eucalyptus-cloud stop || true"
end

execute "Clear $EUCALYPTUS/var/run/eucalyptus" do
	command "rm -rf #{node["eucalyptus"]["home-directory"]}/var/run/eucalyptus/*"
end

execute "Initialize Eucalyptus DB" do
 command "#{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --initialize"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

execute "Wait for credentials." do
  command "#{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --get-credentials admin.zip && unzip -o admin.zip"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 10
  retry_delay 50
end

if node['eucalyptus']['install-load-balancer']
  package "eucalyptus-load-balancer-image" do
    action :install
  end
  execute "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca-install-load-balancer --install-default"
end
