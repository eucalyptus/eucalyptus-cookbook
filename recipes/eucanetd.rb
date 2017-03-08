include_recipe "eucalyptus::default"

# Remove default virsh network which runs its own dhcp server
execute 'virsh net-destroy default' do
  ignore_failure true
end
execute 'virsh net-autostart default --disable' do
  ignore_failure true
end
execute 'virsh net-undefine default' do
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

if node["eucalyptus"]["network"]["mode"] != "VPCMIDO"
  execute "Configure kernel parameters from 70-eucanetd.conf" do
    command "/usr/lib/systemd/systemd-sysctl 70-eucanetd.conf"
    notifies :run, "execute[Ensure bridge modules loaded into the kernel on NC]", :before
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
