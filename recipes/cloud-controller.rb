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

## Install packages for the CLC
package "eucalyptus-cloud" do
  action :install
end

template "/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  mode 0440
  owner "eucalyptus"
  group "eucalyptus"
end

execute "Stop any running cloud process" do
	command "service eucalyptus-cloud stop || true"
end

execute "Clear /var/run/eucalyptus" do
	command "rm -rf /var/run/eucalyptus*"
end

execute "Initialize Eucalyptus DB" do
 command "euca_conf --initialize"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

#The ignore_failure, provider, retries, retry_delay, and supports attributes can be used with any resource or lightweight resources.

execute "Wait for credentials." do
  command "euca_conf --get-credentials admin.zip && unzip -o admin.zip"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 10
  retry_delay 50
end

if node['eucalyptus']['install-load-balancer']
  package "eucalyptus-load-balancer-image" do
    action :install
  end
  #execute "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca-install-load-balancer --install-default"
end
