directory '/root/.euca' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  ignore_failure true
end

bash 'create_admin_creds' do
  cwd ::File.dirname('/root')
  code <<-EOH
    eval `clcadmin-assume-system-credentials`
    DNSDOMAIN=$(euctl | grep dnsdomain | awk '{print $3}')
    euare-useraddkey admin -wd $DNSDOMAIN > /root/.euca/euca-admin.ini
    ACCOUNTID=$(grep account-id /root/.euca/euca-admin.ini | awk '{print $3}')
    grep "user = $ACCOUNTID:admin" /root/.euca/euca-admin.ini
    if [ $? -ne 0 ]; then
      sed -i "/\\[region/auser = $ACCOUNTID:admin" /root/.euca/euca-admin.ini
      echo "[global]" >> /root/.euca/euca-admin.ini; echo "default-region = $DNSDOMAIN" >> /root/.euca/euca-admin.ini
    fi
    euare-useraddloginprofile admin -p Passw0rd --region admin@

    cat > /etc/motd << EOF

------------------------------------------------------------

    * Default region is set to $DNSDOMAIN
    * Default user credentials:
      * account: eucalyptus ($ACCOUNTID)
      * user: arn:aws:iam::$ACCOUNTID:user/admin

    * example command as eucalyptus admin:
      * euserv-describe-services

    ** Login Profile: (requires eucaconsole)
        account: eucalyptus
        username: admin
        password: Passw0rd

------------------------------------------------------------

EOF
    EOH
  ignore_failure true
end
