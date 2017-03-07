require "json"

module CephHelper
  module SetCephRbd

    def self.get_configurations(key_local, key_global)
      if key_local
        Chef::Log.info "Found LOCAL value, ignoring global!"
        return key_local
      elsif key_global
        Chef::Log.info "Couldn't find local value, using GLOBAL!"
        return key_global
      else
        raise Exception.new("Neither global nor local key found!!!")
      end
    end

    def self.is_ceph?(node)
      begin
        cluster_name = Eucalyptus::KeySync.get_local_cluster_name(node)
        if node['eucalyptus']['topology']
          cluster_controller = node['eucalyptus']['topology']['clusters'][cluster_name]
        else
          raise Exception.new("This node doesn't belong to any cluster!!!")
        end
        if cluster_controller["storage-backend"] == "ceph-rbd"
          return true
        end
      rescue Exception => e
        return false
      end
      return false
    end

    def self.is_ceph_radosgw?(node)
      if node['eucalyptus']['topology'] && node['eucalyptus']['topology']['objectstorage']
        objectstorage = node['eucalyptus']['topology']['objectstorage']
      else
        return false
      end
      if objectstorage['providerclient'] == 'ceph-rgw'
          return true
      else
          return false
      end
    end

    def self.make_ceph_config(node, ceph_user)
      if node['ceph'] != nil
        mons = node['ceph']['topology']['mons']
        environment = node.chef_environment
        data = nil
        mons.each do |mon|
          Chef::Log.debug "trying: #{mon}"
          found = Chef::Search::Query.new.search(:node, "addresses:#{mon['ipaddr']}").first.first
          if found.attributes['ceph']['config_data']
            Chef::Log.debug "found: #{found}"
            data = found.attributes['ceph']['config_data']
            break
          end
        end
        conf_file = "/etc/ceph/ceph.conf"
        File.open(conf_file, 'w') do |file|
          file.puts Base64.decode64(data)
        end
        FileUtils.chmod 0640, conf_file
        FileUtils.chown "root", "eucalyptus", conf_file

        keyring_file = "/etc/ceph/ceph.client.#{ceph_user}.keyring"
        keyring_data = nil
        mons.each do |mon|
          Chef::Log.debug "trying: #{mon}"
          found = Chef::Search::Query.new.search(:node, "addresses:#{mon['ipaddr']}").first.first
          if found != nil
            Chef::Log.debug "found: #{found}"
            keyring_data = found.attributes['ceph']['keyring_data'][ceph_user]
            break
          end
        end
        File.open(keyring_file, 'w') do |file|
          file.puts Base64.decode64(keyring_data)
        end
        FileUtils.chmod 0640, keyring_file
        FileUtils.chown "root", "eucalyptus", keyring_file
      else
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

          config_content = ""
          config_data = clusters[name]['ceph_cluster']['ceph_config']

          config_data.each do |section, config_value|
            config_content = "#{config_content}" + "[#{section}]\n"
            config_value.each do |key, value|
              config_content = "#{config_content}" + "  #{key} = #{value}\n"
            end
            file_name = "/etc/ceph/ceph.conf"
            Chef::Log.info "Writing config file: #{file_name}"
            File.open(file_name, 'w') do |file|
              file.puts config_content
            end
          end

        end
      end
    end

    def self.set_ceph_credentials(node, ceph_user)
      self.make_ceph_config(node, ceph_user)
      node.set[:ceph_config_path] = "/etc/ceph/ceph.conf"
      if node['ceph'] != nil
        node.set[:ceph_user_name] = "#{ceph_user}"
        node.set[:ceph_keyring_path] = "/etc/ceph/ceph.client.#{ceph_user}.keyring"
        node.save
      else
        cluster_name = Eucalyptus::KeySync.get_local_cluster_name(node)
        ceph_cluster_user = node['eucalyptus']['topology']['clusters'][cluster_name]['ceph_cluster']['ceph_user']
        file_name = "ceph.client." + ceph_cluster_user + ".keyring"
        node.set[:ceph_user_name] = node['eucalyptus']['topology']['clusters'][cluster_name]['ceph_cluster']['ceph_user']
        node.set[:ceph_keyring_path] = "/etc/ceph/#{file_name}"
        node.save
      end
    end

    def self.get_radosgw_user_creds(node)
      ufses = node['eucalyptus']['topology']['user-facing']
      ufses.each do |ufs|
        Chef::Log.debug "trying: #{ufs}"
        found = Chef::Search::Query.new.search(:node, "addresses:#{ufs}").first.first
        if found.attributes['eucalyptus']['topology']['objectstorage']['access-key']
          Chef::Log.debug "found: #{found}"
          return found
          break
        end
      end
    end

  end
end
