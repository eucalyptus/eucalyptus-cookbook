include_recipe "eucalyptus::default"

if node["eucalyptus"]["install-type"] == "packages"
  yum_package "eucanetd" do
    action :upgrade
    options node['eucalyptus']['yum-options']
  end
else
  include_recipe "eucalyptus::install-source"
end

service "eucanetd" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
