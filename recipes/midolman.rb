pkg_list = %w{java-1.8.0-openjdk-headless midolman}

pkg_list.each do |pkg|
  yum_package pkg do
    action :install
  end
end

zookeepers = []

node['zookeeper']['topology'].each do |zk|
  zookeepers.push("#{zk}:#{node['eucalyptus']['midonet']['zookeeper-port']}")
end

template '/etc/midolman/midolman.conf' do
  source 'midolman.conf.erb'
  variables(
    :zookeepers => zookeepers
  )
  action :create
end

execute 'Set Midolman Template' do
  command "mn-conf template-set -h local -t default"
  not_if { get_midolman_template('default')[:is_configured] }
end

service "restart-midolman" do
  service_name "midolman"
  supports :status => true, :start => true, :stop => true, :restart => true
  action :nothing
  only_if { service_status('midolman')[:is_active] }
end

service "start-midolman" do
  service_name "midolman"
  supports :status => true, :start => true, :stop => true, :restart => true
  action [ :enable, :start ]
  not_if { service_status('midolman')[:is_active] }
end
