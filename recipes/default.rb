#
# Cookbook Name:: eucalyptus
# Recipe:: default
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
directory node['eucalyptus']['home-directory'] do
  recursive true
end
## Init script
if node['eucalyptus']['init-script-url'] != ""
  remote_file "#{node['eucalyptus']['home-directory']}/init.sh" do
    retries 10
    source node['eucalyptus']['init-script-url']
    mode "777"
  end
  execute 'Running init script' do
    command "bash #{node['eucalyptus']['home-directory']}/init.sh"
  end
end

## Create home directory
if node["eucalyptus"]["home-directory"] != "/"
  directory node["eucalyptus"]["home-directory"] do
    owner "eucalyptus"
    group "eucalyptus"
    mode 00750
    action :create
  end
end

if node['eucalyptus']['admin-ssh-pub-key'] != ""
  execute "Add the admins ssh key to authorized keys" do
    command "echo #{node['eucalyptus']['admin-ssh-pub-key']} >> /root/.ssh/authorized_keys"
  end
end

execute "Flush and save iptables" do
  command "iptables -F; iptables -F -t nat; iptables-save > /etc/sysconfig/iptables"
  not_if "service eucalyptus-cc status || service eucanetd status || service eucalyptus-cloud status || service eucalyptus-nc status"
end

## Setup NTP
include_recipe "ntp"
execute "ntpdate -u #{node["eucalyptus"]["ntp-server"]}" do
  cwd '/tmp'
end

## Disable SELinux
selinux_state "SELinux Disabled" do
  action :permissive
end

## Install repo rpms
yum_repository "eucalyptus-release" do
  description "Eucalyptus Package Repo"
  url node["eucalyptus"]["eucalyptus-repo"]
  gpgkey node["eucalyptus"]["eucalyptus-gpg-key"]
  metadata_expire "1"
end

if Eucalyptus::Enterprise.is_enterprise?(node)
  cert_file = "/etc/pki/tls/certs/eucalyptus-enterprise.crt"
  key_file = "/etc/pki/tls/private/eucalyptus-enterprise.key"
  file cert_file do
    content <<-EOH
    -----BEGIN CERTIFICATE-----
    #{node['eucalyptus']['enterprise']['clientcert']}
    -----END CERTIFICATE-----
    EOH
    mode "0700"
  end
  file key_file do
    content <<-EOH
    -----BEGIN RSA PRIVATE KEY-----
    #{node['eucalyptus']['enterprise']['clientkey']}
    -----END RSA PRIVATE KEY-----
    EOH
    mode "0700"
  end
  yum_repository "eucalyptus-enterprise-release" do
    description "Eucalyptus Enterprise Package Repo"
    url node["eucalyptus"]["enterprise-repo"]
    gpgkey node["eucalyptus"]["eucalyptus-gpg-key"]
    sslclientcert cert_file
    sslclientkey key_file
    sslverify node['eucalyptus']['enterprise']['sslverify']
    metadata_expire "1"
  end
end

yum_repository "euca2ools-release" do
  description "Euca2ools Package Repo"
  url node["eucalyptus"]["euca2ools-repo"]
  gpgkey node["eucalyptus"]["euca2ools-gpg-key"]
  metadata_expire "1"
end

remote_file "/tmp/epel-release.rpm" do
  source node["eucalyptus"]["epel-rpm"]
  not_if "rpm -qa | grep 'epel-release'"
end

remote_file "/tmp/elrepo-release.rpm" do
  source node["eucalyptus"]["elrepo-rpm"]
  not_if "rpm -qa | grep 'elrepo-release'"
end

execute 'yum install -y *epel*.rpm' do
  cwd '/tmp'
  not_if "ls /etc/yum.repos.d/epel*"
end

execute 'yum install -y *elrepo*.rpm' do
  cwd '/tmp'
  not_if "ls /etc/yum.repos.d/elrepo*"
end

execute "ssh-keygen -f /root/.ssh/id_rsa -P ''" do
  not_if "ls /root/.ssh/id_rsa"
end

execute 'Add host key' do
  command "ssh-keyscan #{node['ipaddress']} >> /root/.ssh/known_hosts"
  not_if "grep #{node['ipaddress']} /root/.ssh/known_hosts"
end
