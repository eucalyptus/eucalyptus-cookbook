#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install packages for the CLC
%w{eucalyptus-cc}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

service "eucalyptus-cc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
