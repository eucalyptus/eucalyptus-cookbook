#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install packages for the VB
%w{eucalyptus-enterprise-vmware-broker}.each do |pkg|
  yum_package pkg do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
end

service "eucalyptus-cloud" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
