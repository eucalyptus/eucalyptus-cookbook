service "midonet-cluster" do
  service_name "midonet-cluster"
  action :stop
end

pkg_list = %w{midonet-cluster midonet-tools python-midonetclient}

pkg_list.each do |pkg|
  yum_package pkg do
    action :remove
    ignore_failure true
  end
end

directory_list = %w{/etc/midonet-cluster /var/lib/midonet-cluster /var/log/midonet-cluster /usr/share/midonet-cluster}

directory_list.each do |dir|
  directory dir do
    recursive true
    action :delete
    ignore_failure true
  end
end
