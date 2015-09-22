include_recipe "eucalyptus::default"

# this runs only during installation of eucanetd,
# we don't handle reapplying changed ipset max_sets
# during an update here
if node["eucalyptus"]["network"]["mode"] == "EDGE"
  maxsets = node["eucalyptus"]["nc"]["ipset-maxsets"]
  # install ipset if necessary
  execute 'yum install -y ipset' do
    not_if "rpm -q ipset"
  end
  execute 'unload-ipset-hash-net' do
    command 'rmmod ip_set_hash_net'
    ignore_failure true
    action :nothing
  end
  execute 'unload-ipset' do
    command 'rmmod ip_set'
    ignore_failure true
    action :nothing
  end
  execute 'load-ipset' do
    command 'modprobe ip_set'
    action :nothing
  end
  # configure ipset max_sets parameter on NC
  execute "Configure ip_set max_sets options in /etc/modprobe.d/ip_set.conf file" do
    command "echo 'options ip_set max_sets=#{maxsets}' > /etc/modprobe.d/ip_set.conf"
    not_if "grep #{maxsets} /sys/module/ip_set/parameters/max_sets || grep \"options ip_set max_sets=#{maxsets}\" /etc/
    notifies :run, 'execute[unload-ipset-hash-net]', :immediately
    notifies :run, 'execute[unload-ipset]', :immediately
    notifies :run, 'execute[load-ipset]', :immediately
  end
end

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
end

service "eucanetd" do
  action [ :enable, :start ]
  supports :status => true, :start => true, :stop => true, :restart => true
end
