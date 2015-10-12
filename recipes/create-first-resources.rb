#
# Cookbook Name:: eucalyptus
# Recipe:: install-first-resources
#
#Copyright [2014] [Eucalyptus Systems]
##
##Licensed under the Apache License, Version 2.0 (the "License");
##you may not use this file except in compliance with the License.
##You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
##    Unless required by applicable law or agreed to in writing, software
##    distributed under the License is distributed on an "AS IS" BASIS,
##    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##    See the License for the specific language governing permissions and
##    limitations under the License.
##
#

# If the CLC doesn't run user-api services it should redirect to a
# system that does, so we simplify the command line by simply using
# the "localhost" region.
as_admin = "export AWS_DEFAULT_REGION=localhost; eval `clcadmin-assume-system-credentials` && "

execute "Add keypair: my-first-keypair" do
  command "#{as_admin} euca-create-keypair my-first-keypair >/root/my-first-keypair.pem && chmod 0600 /root/my-first-keypair.pem"
  not_if "#{as_admin} euca-describe-keypairs my-first-keypair"
  retries 10
  retry_delay 10
end

execute "Authorizing SSH and ICMP traffic for default security group" do
  command "#{as_admin} euca-authorize -P icmp -t -1:-1 -s 0.0.0.0/0 default && euca-authorize -P tcp -p 22 -s 0.0.0.0/0 default"
end

script "install_image" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  not_if "#{as_admin} euca-describe-images | grep default"
  code <<-EOH
  curl #{node['eucalyptus']['default-img-url']} > default.img
  #{as_admin} euca-install-image -i default.img -b default -n default -r x86_64 --virtualization-type hvm
  EOH
end


execute "Ensure default image is public" do
  command "#{as_admin} euca-modify-image-attribute -l -a all $(euca-describe-images | grep default | grep emi | awk '{print $2}')"
end

execute "Wait for resource availability" do
  command "#{as_admin} euca-describe-availability-zones verbose | grep m1.small | grep -v 0000"
  retries 50
  retry_delay 10
end

execute "Running an instance" do
  command "#{as_admin} euca-run-instances -k my-first-keypair $(euca-describe-images | grep default | grep emi | cut -f 2)"
end
