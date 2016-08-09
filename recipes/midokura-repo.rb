username = node['eucalyptus']['midonet']['repo-username']
password = node['eucalyptus']['midonet']['repo-password']
mem_urn = node['eucalyptus']['midonet']['mem-urn']
mem_gpgkey = node['eucalyptus']['midonet']['gpgkey']
mem_misc = node['eucalyptus']['midonet']['mics-url']

yum_repository "midokura" do
  description "Midokura Enterprise MidoNet"
  baseurl "http://#{username}:#{password}@#{mem_urn}"
  gpgcheck true
  gpgkey mem_gpgkey
  enabled true
  action :create
end

yum_repository "midokura-misc" do
  description "MEM 3rd Party Tools and Libraries"
  baseurl mem_misc
  gpgcheck true
  gpgkey mem_gpgkey
  enabled true
  action :create
end
