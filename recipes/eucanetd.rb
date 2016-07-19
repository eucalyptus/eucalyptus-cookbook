include_recipe "eucalyptus::default"

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucanetd" do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
else
  include_recipe "eucalyptus::install-source"
end

execute "Configure kernel parameters from 70-eucanetd.conf" do
  command "/usr/lib/systemd/systemd-sysctl 70-eucanetd.conf"
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
  notifies :restart, 'service[eucanetd]', :immediately
end

service "eucanetd" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
