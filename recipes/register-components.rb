#
# Cookbook Name:: eucalyptus
# Recipe:: register-components
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

##### Register clusters
clusters = node["eucalyptus"]["topology"]["clusters"]
clusters.each do |cluster, info|
  if info["cc-1"] == ""
	cc_ip = node['ipaddress']
  else
	cc_ip = info["cc-1"]
  end
  execute "Register CC" do
    command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca_conf --register-cluster -P #{cluster} -H #{cc_ip} -C #{cluster}-cc-1"
  end
  if info["sc-1"] == ""
	sc_ip = node['ipaddress']
  else
	sc_ip = info["sc-1"]
  end
  execute "Register SC" do
    command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca_conf --register-sc -P #{cluster} -H #{sc_ip} -C #{cluster}-sc-1"
  end
end

if node['eucalyptus']['topology']['walrus'] == ""
    walrus_ip = node['ipaddress']
else
    walrus_ip = node['eucalyptus']['topology']['walrus']
end
##### Register Walrus
execute "Register Walrus" do
  command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca_conf --register-walrus -P walrus -H #{walrus_ip} -C walrus-1"
end
