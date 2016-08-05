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

bgp_peers = node['eucalyptus']['midonet']['bgp-peers']

bgp_peers.each do |bgp_info|
  bash "Doing BGP entry for: router=#{bgp_info['router-name']}  port-ip=#{bgp_info['port-ip']}" do
    code <<-EOH
      ROUTER_ID=$(#{midonet_command_prefix} list router name eucart | awk '{print $2}')
      PORT_ID=$(#{midonet_command_prefix} router $ROUTER_ID list port address #{bgp_info['port-ip']} | awk '{print $2}')

      CHECK_ASN="#{midonet_command_prefix} list router name eucart | grep #{bgp_info['local-as']}"
      SET_ASN="#{midonet_command_prefix} router name eucart set asn #{bgp_info['local-as']}"
      if eval $CHECK_ASN; then
         echo "Local ASN already configured."
      else
        echo "Setting up local ASN."
        eval $SET_ASN
      fi
      CHECK_BGP_PEER=$(#{midonet_command_prefix} list router name eucart bgp-peer)
      if [[ ! -z $CHECK_BGP_PEER ]]; then
        echo "BGP Peer already configured."
        BGP_PEER_ID=$(#{midonet_command_prefix} list router name eucart bgp-peer | awk '{print $2}')
      else
        BGP_PEER_ID=$(#{midonet_command_prefix} router name eucart add bgp-peer asn #{bgp_info['remote-as']} address #{bgp_info['peer-address']})
        echo "Setting up BGP Peer."
      fi

      CHECK_BGP_NETWORK="#{midonet_command_prefix} router name eucart bgp-network list | grep #{bgp_info['route']}"
      ADD_BGP_NETWORK="#{midonet_command_prefix} router name eucart add bgp-network net #{bgp_info['route']}"
      if eval $CHECK_BGP_NETWORK; then
         echo "BGP Network already configured."
      else
        echo "Setting up BGP Network."
        eval $ADD_BGP_NETWORK
      fi
    EOH
    flags '-xe'
    retries 10
    retry_delay 20
  end
end unless bgp_peers.nil?
