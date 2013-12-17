#
# Cookbook Name:: eucalyptus
# Recipe:: install-first-resources
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

execute "Add keypair: my-first-keypair" do
  command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca-create-keypair my-first-keypair >/root/my-first-keypair && chmod 0600 /root/my-first-keypair"
end

execute "Authorizing SSH and ICMP traffic for default security group" do
  command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca-authorize -P icmp -t -1:-1 -s 0.0.0.0/0 default && euca-authorize -P tcp -p 22 -s 0.0.0.0/0 default"
end

execute "Install default image" do
  command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && eustore-install-image -b my-first-image -i $(eustore-describe-images | egrep \"#{node["eucalyptus"]["default-image"]}.*kvm\" | head -1 | cut -f 1)"
end

execute "Wait for resource availability" do
  command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca-describe-availability-zones verbose | grep m1.small | grep -v 0000"
  retries 50
  retry_delay 10
end

execute "Running an instance" do
  command "source #{node['eucalyptus']['admin-cred-dir']}/eucarc && euca-run-instances -k my-first-keypair $(euca-describe-images | grep my-first-image | grep emi | cut -f 2)"
end
