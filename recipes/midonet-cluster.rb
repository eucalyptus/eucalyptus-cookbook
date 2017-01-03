midonet_url = "http://#{node['eucalyptus']['midonet']['http-host']}:#{node['eucalyptus']['midonet']['http-port']}/midonet-api"

pkg_list = %w{midonet-cluster python-midonetclient}

pkg_list.each do |pkg|
  yum_package pkg do
    action :install
  end
end

zookeepers = []

node['cassandra']['topology'].each do |zk|
  zookeepers.push("#{zk}:#{node['eucalyptus']['midonet']['zookeeper-port']}")
end

template '/etc/midonet/midonet.conf' do
  source 'midonet.conf.erb'
  variables(
    :zookeepers => zookeepers
  )
  action :create
end

bash 'Set up access to the NSDB' do
  user 'root'
  code <<-EOH
cat << EOF | mn-conf set -t default
zookeeper {
  zookeeper_hosts = "#{zookeepers.join(',')}"
}

cassandra {
  servers = "#{node['cassandra']['topology'].join(',')}"
}
EOF
  EOH
  only_if { get_mn_template('default')[:is_empty] }
end

execute 'Set MidoNet HTTP Port' do
  command "mn-conf set cluster.rest_api.http_port=#{node['eucalyptus']['midonet']['http-port']}"
  not_if { get_mn_http_port(node['eucalyptus']['midonet']['http-port'])[:is_configured] }
end

execute 'Set MidoNet HTTP Port' do
  command "mn-conf set cluster.rest_api.http_host=#{node['eucalyptus']['midonet']['http-host']}"
  not_if { get_mn_http_host(node['eucalyptus']['midonet']['http-host'])[:is_configured] }
end

service "restart-midonet-cluster" do
  service_name "midonet-cluster"
  supports :status => true, :start => true, :stop => true, :restart => true
  action :nothing
  only_if "midonet-cli -e -A --midonet-url=#{midonet_url}"
end

service "start-midonet-cluster" do
  service_name "midonet-cluster"
  supports :status => true, :start => true, :stop => true, :restart => true
  action [ :enable, :start ]
  not_if { service_status('midonet-cluster')[:is_active] }
end
