module CephHelper
  module SetCephRbd

    def self.is_ceph?(node)
      if node['eucalyptus']['topology']
        clusters = node['eucalyptus']['topology']['clusters']
      else
        return false
      end
      clusters.each do |name, info|
        if info['storage-backend'] == 'ceph-rbd'
          return true
        else
          return false
        end
      end
    end

    def self.make_ceph_config(node)
      clusters = node['eucalyptus']['topology']['clusters']

      clusters.each do |name, info|
        ceph_cluster_user = node['eucalyptus']['topology']['clusters'][name]['ceph_cluster']['ceph_user']

        keyring_content = "[client." + ceph_cluster_user + "]\n\t"

        ceph_cluster_keyring = node['eucalyptus']['topology']['clusters'][name]['ceph_cluster']['keyring']
        ceph_cluster_keyring.each do |keyring_key, keyring_value|
          keyring_content = "#{keyring_content}" + "#{keyring_key} = #{keyring_value}\n"
        end

        file_name = "/etc/ceph/ceph.client." + ceph_cluster_user + ".keyring"
        Chef::Log.info "Writing keyring file: #{file_name}"
        File.open(file_name, 'w') do |file|
          file.puts keyring_content
        end
        FileUtils.chmod 0744, file_name

        config_content = "[global]\n"
        ceph_cluster_global = node['eucalyptus']['topology']['clusters'][name]['ceph_cluster']['global']
        ceph_cluster_global.each do |ceph_key, ceph_value|
          Chef::Log.info "shaon - cluster_detail: name: #{ceph_key} and info: #{ceph_value}"
          config_content = "#{config_content}" + "#{ceph_key} = #{ceph_value}\n"
        end

        config_content = "#{config_content}" + "[mon]\n"
        ceph_cluster_mon = node['eucalyptus']['topology']['clusters'][name]['ceph_cluster']['mon']
        ceph_cluster_mon.each do |ceph_key, ceph_value|
          Chef::Log.info "shaon - cluster_detail: name: #{ceph_key} and info: #{ceph_value}"
          config_content = "#{config_content}" + "#{ceph_key} = #{ceph_value}\n"
        end

        file_name = "/etc/ceph/ceph.conf"
        Chef::Log.info "Writing config file: #{file_name}"
        File.open(file_name, 'w') do |file|
          file.puts config_content
        end
      end
    end

    def self.set_ceph_credentials(node)
      self.make_ceph_config(node)
      cluster_name = Eucalyptus::KeySync.get_local_cluster_name(node)
      ceph_cluster_user = node['eucalyptus']['topology']['clusters'][cluster_name]['ceph_cluster']['ceph_user']
      file_name = "ceph.client." + ceph_cluster_user + ".keyring"
      if ::File.exists?('/etc/eucalyptus/eucalyptus.conf')
        Chef::Log.info "Writing to /etc/eucalyptus/eucalyptus.conf file"
        file = Chef::Util::FileEdit.new("/etc/eucalyptus/eucalyptus.conf")
        file.insert_line_if_no_match("/CEPH_USER_NAME=\"#{ceph_cluster_user}\"/", "CEPH_USER_NAME=\"#{ceph_cluster_user}\"")
        file.insert_line_if_no_match("/CEPH_KEYRING_PATH=\"/etc/ceph/#{file_name}\"/", "CEPH_KEYRING_PATH=\"/etc/ceph/#{file_name}\"")
        file.insert_line_if_no_match("/CEPH_CONFIG_PATH=\"/etc/ceph/ceph.conf\"/", "CEPH_CONFIG_PATH=\"/etc/ceph/ceph.conf\"")
        file.write_file
      end
    end

  end
end
