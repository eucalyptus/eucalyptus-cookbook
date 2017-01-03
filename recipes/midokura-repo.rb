username = node['eucalyptus']['midonet']['repo-username']
password = node['eucalyptus']['midonet']['repo-password']
mem_urn = node['eucalyptus']['midonet']['mem-urn']

midonet_baseurl = node['eucalyptus']['midonet']['midonet-url']
misc_url = node['eucalyptus']['midonet']['misc-url']
gpgkey = node['eucalyptus']['midonet']['gpgkey']

if node['eucalyptus']['midonet']['auth']
  midonet_baseurl = "http://#{username}:#{password}@#{mem_urn}"
  misc_url = node['eucalyptus']['midonet']['mem-misc-url']
  gpgkey = node['eucalyptus']['midonet']['mem-gpgkey']
end

Chef::Log.info midonet_baseurl

yum_repository "midokura" do
  description "Midokura Enterprise MidoNet"
  baseurl midonet_baseurl
  gpgcheck true
  gpgkey gpgkey
  enabled true
  action :create
end

yum_repository "midokura-misc" do
  description "MEM 3rd Party Tools and Libraries"
  baseurl misc_url
  gpgcheck true
  gpgkey gpgkey
  enabled true
  action :create
end
