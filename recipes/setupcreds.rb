directory '/root/.euca' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

bash 'extract_module' do
  cwd ::File.dirname('/root')
  code <<-EOH
    eval `clcadmin-assume-system-credentials`
    dnsdomain=$(euctl | grep dnsdomain | awk '{print $3}')
    euare-useraddkey admin -wd $dnsdomain > /root/.euca/euca-admin.ini
    echo "[global]" >> /root/.euca/euca-admin.ini; echo "default-region = $dnsdomain" >> /root/.euca/euca-admin.ini
    euare-useraddloginprofile admin -p foobar --region admin@

    cat > /etc/motd << EOF

------------------------------------------------------------
    ** Eucalyptus Admin credentials:
    `grep user /root/.euca/euca-admin.ini`
        `grep key-id /root/.euca/euca-admin.ini`
        `grep secret-key /root/.euca/euca-admin.ini`
        `grep account-id /root/.euca/euca-admin.ini`

    ** admin example:
        euserv-describe-services --region admin@

    ** Login Profile: (requires eucaconsole)
        account: eucalyptus
        username: admin
        password: foobar
------------------------------------------------------------

EOF
    EOH
end
