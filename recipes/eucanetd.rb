# used for platform_version comparison
require 'chef/version_constraint'

include_recipe "eucalyptus::default"

# Remove default virsh network which runs its own dhcp server
execute 'virsh net-destroy default' do
  ignore_failure true
end
execute 'virsh net-autostart default --disable' do
  ignore_failure true
end

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucanetd" do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
else
  include_recipe "eucalyptus::install-source"
end

execute "Run systemd-modules-load" do
  command '/usr/lib/systemd/systemd-modules-load || :'
  action :nothing
end

if Chef::VersionConstraint.new("~> 6.0").include?(node['platform_version'])
  execute "Set ip_forward sysctl values in sysctl.conf" do
    command "sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf"
  end
  execute "Set bridge-nf-call-iptables sysctl values in sysctl.conf" do
    command "sed -i 's/net.bridge.bridge-nf-call-iptables.*/net.bridge.bridge-nf-call-iptables = 1/' /etc/sysctl.conf"
  end
  execute "Reload sysctl values" do
    command "sysctl -p"
  end
end
if Chef::VersionConstraint.new("~> 7.0").include?(node['platform_version'])
  if node["eucalyptus"]["network"]["mode"] != "VPCMIDO"
    execute "Configure kernel parameters from 70-eucanetd.conf" do
      command "/usr/lib/systemd/systemd-sysctl 70-eucanetd.conf"
      notifies :run, "execute[Ensure bridge modules loaded into the kernel on NC]", :before
    end
  end
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
  notifies :restart, 'service[eucanetd]', :delayed
end

service "eucanetd" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
  notifies :restart, 'service[eucanetd]', :delayed
end
