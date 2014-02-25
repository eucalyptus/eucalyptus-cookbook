#
# Cookbook Name:: eucalyptus
# Recipe:: register-components
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

##### Register nodes
cluster = node["eucalyptus"]["topology"]["clusters"][node["eucalyptus"]["local-cluster-name"]]
if cluster['nodes'] == ""
  nodes = node["ipaddress"]
else
  nodes = cluster['nodes']
end

ruby_block "Save node list" do
  block do
    node.set["eucalyptus"]["topology"]["clusters"][node["eucalyptus"]["local-cluster-name"]]["nodes"] = nodes
    node.save
  end
  not_if "#{Chef::Config[:solo]}"
end

nodes.split().each do |nc_ip|
  ssh_known_hosts_entry nc_ip
  execute "Register Nodes" do
    command "#{node['eucalyptus']['home-directory']}/usr/sbin/euca_conf --register-nodes #{nc_ip}"
  end
end

