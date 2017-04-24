midonet_url = "http://#{node['eucalyptus']['midonet']['http-host']}:#{node['eucalyptus']['midonet']['http-port']}/midonet-api"
midonet_command_prefix = "midonet-cli -A --midonet-url=#{midonet_url} -e"
tunnel_zone_name = node['eucalyptus']['midonet']['default-tunnel-zone']

Chef::Log.info "#{midonet_url}"
Chef::Log.info "#{midonet_command_prefix}"

execute 'Create TunnelZone' do
  command "#{midonet_command_prefix} add tunnel-zone name #{tunnel_zone_name} type gre"
  retries 20
  retry_delay 10
  not_if "#{midonet_command_prefix} list tunnel-zone | grep #{tunnel_zone_name}"
end


### Add hosts to tunnel zone
members=`#{midonet_command_prefix} -e list tunnel-zone name #{tunnel_zone_name} member`

midolman_hosts = node['eucalyptus']['midonet']['midolman-host-mapping']

Chef::Log.info "Attaching Midolman Hosts: #{midolman_hosts}"
midolman_hosts.each do |hostname, host_ip|
  bash "Configure host: #{hostname}" do
    code <<-EOH
    TZID=`#{midonet_command_prefix} -e list tunnel-zone | grep $TZONE_NAME | awk '{print $2}'`
    HOSTID=`#{midonet_command_prefix} -e host list | grep $HOSTNAME | awk '{print $2}'`
    #{midonet_command_prefix} -e tunnel-zone $TZID add member host $HOSTID address $HOST_IP
    EOH
    environment  'TZONE_NAME' => tunnel_zone_name, 'HOSTNAME' => hostname, 'HOST_IP' => host_ip
    flags '-xe'
    retries 10
    retry_delay 20
    #not_if "#{midonet_command_prefix} -e list tunnel-zone name #{tunnel_zone_name} member | grep #{host_ip}"
    not_if "echo \"#{members}\" | grep \"address #{host_ip}$\""
  end
  members << "address #{host_ip}\n"
end
