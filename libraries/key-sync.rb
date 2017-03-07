#
# Cookbook Name:: eucalyptus
# Library:: keys-sync
#
#Copyright [2014] [Eucalyptus Systems]
##
##Licensed under the Apache License, Version 2.0 (the "License");
##you may not use this file except in compliance with the License.
##You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
##    Unless required by applicable law or agreed to in writing, software
##    distributed under the License is distributed on an "AS IS" BASIS,
##    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##    See the License for the specific language governing permissions and
##    limitations under the License.
##
#
require "chef/search/query"
require "chef/log"
require 'fileutils'

module Eucalyptus
  module KeySync
    def self.upload_cloud_keys(node)
      cloud_keys_dir = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys"
      %w(cloud-cert.pem cloud-pk.pem euca.p12).each do |key_name|
        cert = Base64.encode64(::File.new("#{cloud_keys_dir}/#{key_name}").read)
        node.set['eucalyptus']['cloud-keys'][key_name] = cert
        node.save
      end
    end

    def self.get_local_cluster_name(node)
      node["eucalyptus"]["topology"]["clusters"].each do |name, info|
        Chef::Log.info "Found cluster #{name} with attributes: #{info}"
        addresses = []
        node["network"]["interfaces"].each do |interface, info|
          if info["addresses"]
            info["addresses"].each do |address, info|
              addresses.push(address)
            end
          end
        end
        Chef::Log.info "Found addresses: " + addresses.join("  ")
        all_cluster_machines = []
        info["sc"].each do |sc_ip|
          all_cluster_machines << sc_ip
        end
        info["cc"].each do |cc_ip|
          all_cluster_machines << cc_ip
        end
        info["nodes"].each do |node_ip|
          all_cluster_machines << node_ip
        end
        Chef::Log.info "Machines in #{name} cluster: " + all_cluster_machines.join("  ")
        all_cluster_machines.each do |ip|
          if addresses.include?(ip)
              Chef::Log.info "Setting cluster name to: " + name
              return name
          end
        end
      end
      raise "Unable to determine local cluster name for #{node[:ipaddress]}"
    end

    def self.get_cluster_keys(node, component)
      local_cluster_name = self.get_local_cluster_name(node)
      clc = self.get_clc(node)
      cluster_keys = clc.attributes["eucalyptus"]["cloud-keys"][local_cluster_name]
      euca_p12 = clc.attributes["eucalyptus"]["cloud-keys"]["euca.p12"]
      ### Write cluster keys to disk
      cluster_keys.each do |key_name,data|
       file_name = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{key_name}"
       if data.is_a?(String)
         File.open(file_name, 'w') do |file|
           file.puts Base64.decode64(data)
         end
       end
       FileUtils.chmod 0700, file_name
       FileUtils.chown 'eucalyptus', 'eucalyptus', file_name
      end

      ### Also put in place euca.p12
      file_name = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/euca.p12"
      File.open(file_name, 'w') do |file|
        file.puts Base64.decode64(euca_p12)
      end
      FileUtils.chmod 0700, file_name
      FileUtils.chown 'eucalyptus', 'eucalyptus', file_name
    end

    def self.get_node_keys(node)
      local_cluster_name = self.get_local_cluster_name(node)
      clc = self.get_clc(node)
      cluster_keys = clc.attributes["eucalyptus"]["cloud-keys"][local_cluster_name]
      cluster_keys.each do |key_name,data|
        file_name = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{key_name}"
        File.open(file_name, 'w') do |file|
          file.puts Base64.decode64(data)
        end
        FileUtils.chmod 0700, file_name
        FileUtils.chown 'eucalyptus', 'eucalyptus', file_name
      end
    end

    def self.get_cloud_keys(node)
      clc = self.get_clc(node)
      clc.attributes["eucalyptus"]["cloud-keys"].each do |key_name, data|
        if data.is_a? String
          file_name = "#{node["eucalyptus"]["home-directory"]}/var/lib/eucalyptus/keys/#{key_name}"
          File.open(file_name, 'w') do |file|
            file.puts Base64.decode64(data)
          end
          FileUtils.chmod 0700, file_name
          FileUtils.chown 'eucalyptus', 'eucalyptus', file_name
        end
      end
    end

    def self.get_clc(node)
      clc = nil
      if node.recipe? "eucalyptus::cloud-controller"
        clc = node
      else
        retry_count = 1
        retry_delay = 10
        total_retries = 12
        begin
          clc_ips = node["eucalyptus"]["topology"]["clc"]
          clc_ips.each do |clc_ip|
            environment = node.chef_environment
            Chef::Log.info "Getting keys from CLC #{clc_ip}"
            clc = Chef::Search::Query.new.search(:node, "addresses:#{clc_ip}").first.first
            if clc.nil?
              raise "Unable to find CLC:#{clc_ip} on chef server"
            end
          end
        rescue Exception => e
          if retry_count < total_retries
            sleep retry_delay
            retry_count += 1
            Chef::Log.info "Retrying search for CLC:#{clc_ip}"
            retry
          else
            raise e
          end
        end
      end
      return clc
    end
  end
end
