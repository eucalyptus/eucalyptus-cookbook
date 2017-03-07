service "midolman" do
  service_name "midolman"
  action :stop
end

pkg_list = %w{midolman midonet-tools quagga}

pkg_list.each do |pkg|
  yum_package pkg do
    action :remove
    ignore_failure true
  end
end

directory_list = %w{/etc/midolman /var/lib/midolman /var/log/midolman /usr/lib/midolman /usr/share/doc/midolman /usr/share/midolman}

directory_list.each do |dir|
  directory dir do
    recursive true
    action :delete
    ignore_failure true
  end
end
