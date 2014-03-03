#
# Cookbook Name:: eucalyptus
# Recipe:: register-components
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

clusters = node["eucalyptus"]["topology"]["clusters"]
command_prefix = "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && #{node['eucalyptus']['home-directory']}"
modify_property = "#{command_prefix}/usr/sbin/euca-modify-property"
clusters.each do |cluster, info|
  ### Set backend
  execute "Set storage backend" do
     command "#{modify_property} -p #{cluster}.storage.blockstoragemanager=#{info["storage-backend"]} | grep #{info["storage-backend"]}"
     retries 10
     retry_delay 30
  end
  ### Configure backend
  case info["storage-backend"]
  when "das"  
    execute "Set das device" do
      command "#{modify_property} -p #{cluster}.storage.dasdevice=#{info["das-device"]} | grep #{info["das-device"]}"
      retries 10
      retry_delay 30
    end
  end
end
