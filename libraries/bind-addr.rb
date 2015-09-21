#
# Cookbook Name:: eucalyptus
# Library:: bind-addr
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

module Eucalyptus
  module BindAddr
    def self.get_bind_interface_ip(node)
      bind_interface = node["eucalyptus"]["bind-interface"]
      raise "Setting the bind interface was requested but not bind-interface parameter was set" if bind_interface.nil?
      if node["network"]["interfaces"].has_key? bind_interface
        bind_addr = node[:network][:interfaces][bind_interface][:addresses].find {|addr, addr_info| addr_info[:family] == "inet"}.first
        bind_addr
      else
        raise "Unable to find requested bind interface #{bind_interface} on #{node["ipaddress"]}"
      end
    end
  end
end
