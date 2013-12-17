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
execute "Register Nodes" do
  command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && #{node['eucalyptus']['home-directory']}/usr/sbin/euca_conf --register-nodes #{nodes}"
end
