#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

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

execute "Initialize Eucalyptus DB" do
 command "euca_conf --initialize"
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end

if node['eucalyptus']['install-load-balancer']
  package "eucalyptus-load-balancer-image" do
    action :install
  end
end
