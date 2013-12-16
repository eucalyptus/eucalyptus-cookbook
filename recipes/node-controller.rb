#
# Cookbook Name:: eucalyptus
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

## Install packages for the NC

include_recipe "bridger"

node[:bridger][:interface] = node["eucalyptus"]["network"]["public-interface"] # (interface to bridge to)
node[:bridger][:name] = node["eucalyptus"]["network"]["bridge-interface"] # (name of the bridge)
### Need to add these to config
node[:bridger][:dhcp] = 'true' # (dhcp in use on interface)
#node[:bridger][:address] = nil # (static address to use)
#node[:bridger][:netmask] = '255.255.255.0' # (netmask in use)
#node[:bridger][:gateway] = nil # (gateway to use)

if node["eucalyptus"]["install-type"] == "package"
  %w{eucalyptus-nc}.each do |pkg|
    package pkg do
      action :upgrade
    end
  end
else
  execute "usermod -a -G kvm eucalyptus"
  execute "cp #{node["eucalyptus"]["home-directory"]}/source/tools/eucalyptus-nc-libvirt.pkla /var/lib/polkit-1/localauthority/10-vendor.d/eucalyptus-nc-libvirt.pkla"
  execute "dbus-uuidgen > /var/lib/dbus/machine-id && service messagebus restart"

end

service "eucalyptus-nc" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
