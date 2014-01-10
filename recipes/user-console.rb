#
# Cookbook Name:: eucalyptus
# Recipe:: eucalyptus-console
#
# Copyright 2013, Eucalyptus Systems
#
# All rights reserved - Do Not Redistribute
#

## Install packages for the user-console

yum_repository "eucalyptus-console" do
   description "Eucalyptus Console Repo"
   url node["eucalyptus"]["user-console-repo"]
   only_if { node['eucalyptus']['user-console-repo'] != '' }
end

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucalyptus-console" do
    action :install
    options node['eucalyptus']['yum-options']
  end
#else
  ## Source install stuff here
end

service "eucalyptus-console" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
