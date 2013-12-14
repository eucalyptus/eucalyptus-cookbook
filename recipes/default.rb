#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Setup NTP
include_recipe "ntp"

## Disable SELinux
include_recipe "selinux"
selinux_state "SELinux Disabled" do
  action :disabled
end

## Install repo rpms
remote_file "/tmp/eucalyptus-release.rpm" do
  source node["eucalyptus"]["release-rpm"]
  not_if "rpm -qa | grep -qx 'eucalyptus-release'"
end

remote_file "/tmp/euca2ools-release.rpm" do
  source node["eucalyptus"]["euca2ools-rpm"]
  not_if "rpm -qa | grep -qx 'euca2ools-release'"
end

remote_file "/tmp/epel-release.rpm" do
  source node["eucalyptus"]["epel-rpm"]
  not_if "rpm -qa | grep -qx 'epel-release'"
end

remote_file "/tmp/elrepo-release.rpm" do
  source node["eucalyptus"]["elrepo-rpm"]
  not_if "rpm -qa | grep -qx 'elrepo-release'"
end

execute 'yum install -y *release*.rpm' do
  cwd '/tmp'
end
