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
command_prefix = "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && #{node['eucalyptus']['home-directory']}"
euca_conf = "#{command_prefix}/usr/sbin/euca_conf"
modify_property = "#{command_prefix}/usr/sbin/euca-modify-property"
clusters.each do |cluster, info|
  if info["cc-1"] == ""
	cc_ip = node['ipaddress']
  else
	cc_ip = info["cc-1"]
  end
  execute "Register CC" do
    command "#{euca_conf} --register-cluster -P #{cluster} -H #{cc_ip} -C #{cluster}-cc-1"
  end
  if info["sc-1"] == ""
	sc_ip = node['ipaddress']
  else
	sc_ip = info["sc-1"]
  end
  execute "Register SC" do
    command "#{euca_conf} --register-sc -P #{cluster} -H #{sc_ip} -C #{cluster}-sc-1"
  end
  execute "Set storage backend" do
     command "#{modify_property} -p default.storage.blockstoragemanager=#{info["storage-backend"]}"
  end
end

### If this is 4.0 we need to register an OSG
execute "Register OSG" do
  command "#{euca_conf} --register-osg -P osg -H #{osg_ip} -C osg-1"
  only_if "grep 4.0 #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
end

if node['eucalyptus']['topology']['riak']['endpoint'] != ""
  ### Setup for riak integration
  execute "#{modify_property} -p objectstorage.providerclient=s3"
  execute "#{modify_property} -p objectstorage.s3provider.s3endpoint=#{node['eucalyptus']['topology']['riak']['endpoint']}"
  execute "#{modify_property} -p objectstorage.s3provider.s3accesskey=#{node['eucalyptus']['topology']['riak']['access-key']}"
  execute "#{modify_property} -p objectstorage.s3provider.s3secretkey=#{node['eucalyptus']['topology']['riak']['secret-key']}"
else
  ### Use legacy walrus

  ### In 4.0 need to setup OSG to point to Walrus
  execute "Set OSG providerclient" do
    command "#{modify_property} -p objectstorage.providerclient=walrus"
    only_if "grep 4.0 #{node['eucalyptus']['home-directory']}/etc/eucalyptus/eucalyptus-version"
  end

  ### Get correct walrus IP
  if node['eucalyptus']['topology']['walrus'] == ""
      walrus_ip = node['ipaddress']
  else
      walrus_ip = node['eucalyptus']['topology']['walrus']
  end

  ##### Register Walrus
  execute "Register Walrus" do
    command "#{euca_conf} --register-walrus -P walrus -H #{walrus_ip} -C walrus-1"
  end
end

execute "Wait for credentials with S3 URL populated" do
  command "rm -rf admin.zip && #{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --get-credentials admin.zip && unzip -o admin.zip"
  cwd node['eucalyptus']['admin-cred-dir']
  retries 10
  retry_delay 50
end

### Register ELB Image
if node['eucalyptus']['install-load-balancer']
  yum_package "eucalyptus-load-balancer-image" do
    action :install
    options node['eucalyptus']['yum-options']
  end
  execute "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca-install-load-balancer --install-default"
end
