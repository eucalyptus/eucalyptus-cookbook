#
# Cookbook Name:: eucalyptus
# Recipe:: eutester
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install packages eutester
%w{python-setuptools gcc make python-devel}.each do |pkg|
  package pkg do
    action :install
  end
end

easy_install_package "eutester" do
	  action :install
end
