include_recipe "eucalyptus::default"

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucanetd" do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
else
  include_recipe "eucalyptus::install-source"
end

template "#{node["eucalyptus"]["home-directory"]}/etc/eucalyptus/eucalyptus.conf" do
  source "eucalyptus.conf.erb"
  action :create
  notifies :restart, 'service[eucanetd]', :immediately
end

service "eucanetd" do
  case node['platform']
  when 'centos','redhat'
    provider Chef::Provider::Service::Init
    # FIXME - mbacchi remember to add :enable to actions below when fully functioning with systemd
    action [ :start ]
    supports :status => true, :start => true, :stop => true, :restart => true
  end
end
