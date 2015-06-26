# This library is inspired from
# https://github.com/hectcastro/chef-riak-cs-create-admin-user

require "net/http"
require "json"
require "uri"

module RiakCSHelper
  module CreateUser
    USER_RESOURCE_PATH = "riak-cs/user"

    def self.create_riakcs_user(name, email, fqdn, port)
      Chef::Log.info "Creating RiakCS user..."
      Chef::Log.info "Username: #{name} and email: #{email}"
      Chef::Log.info "RiakCS URL: http://#{fqdn}:#{port}/#{USER_RESOURCE_PATH}"

      uri = URI.parse("http://#{fqdn}:#{port}/#{USER_RESOURCE_PATH}")
      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.body  = {
        "email" => email,
        "name"  => name
      }.to_json

      http = Net::HTTP.new(uri.host, uri.port)
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      response = http.request(request)
      json = JSON.parse(response.body)

      [ json["key_id"], json["key_secret"] ]

    rescue => e
      Chef::Log.warn "Error occurred trying to create admin user: #{e.inspect}"
      raise e
    end

    def self.download_riak_credentials(node)
      head = nil
      head_ip = node['riakcs_cluster']['topology']['head']['ipaddr']
      environment = node.chef_environment
      Chef::Log.info "Getting all attributes from head"
      head = Chef::Search::Query.new.search(:node, "addresses:#{head_ip}").first.first
      cert = head.attributes['riak_cs']['credentials']
      node.set['riak_cs']['credentials'] = cert
      node.save

      file_name = "/root/creds.txt"
      File.open(file_name, 'w') do |file|
        file.puts Base64.decode64(node['riak_cs']['credentials'])
      end
      FileUtils.chmod 0644, file_name
      hash = Hash[File.read('/root/creds.txt').split("\n").map{|i|i.split(':')}]
      admin_key = hash['RIAKCS_ACCESS_KEY_ID']
      admin_secret = hash['RIAKCS_SECRET_ACCESS_KEY']

      [ admin_key, admin_secret ]
    end

  end
end
