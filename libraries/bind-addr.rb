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
require 'ipaddr'

module Eucalyptus
    module BindAddr
        # Attempt to find the address to bind the Eucalyptus service to based upon the provided
        # params; bind-interface, and/or bind-network
        def self.get_bind_interface_ip(node)
            bind_interface = node["eucalyptus"]["bind-interface"]
            bind_network = node["eucalyptus"]["bind-network"]
            if bind_network.nil? && bind_interface.nil?
                raise "set-bind-addr set to True requires at least one of bind-interface or bind-network params to be set"
	        end
            # First try finding the interface(s) in the bind network if provided.
            bind_addr = nil
            if bind_network
                bindaddrs = {}
                for iface in node[:network][:interfaces]
                    if iface.is_a?(Array) && iface.length() > 1
                        iface_name = iface[0]
                        iface_hash = iface[1]
                        if iface_hash.is_a?(Hash) && iface_hash.has_key?('addresses') and iface_hash['addresses'].is_a?(Hash)
                            addresses = iface_hash['addresses']
                            address.each do |addr, addr_info|
                                addr_info = addresses[addr]
                                if addr_info.is_a?(Hash) && addr_info.has_key?('family') && addr_info['family'] == "inet"
                                    ifaceaddr = IPAddr.new(addr)
                                    if bindnetwork.include?(ifaceaddr)
                                        print "Got a match, iface: #{iface_name} , address: #{addr}\n"
                                        bindaddrs[iface_name] = addr
                                    end
                                end
                            end
                        end
                    end
                    if !bindaddrs.empty?
                        if bindaddrs.length > 1
                            if (!bind_interace.nil? && !bind_interface.empty?)
                                bindaddrs.each do |iface, addr|
                                    if iface == bind_interface
                                        bind_addr = addr
                                        break
                                    end
                                end
                            end
		                    end
                        if bindaddr.nil? && bindaddrs.length > 0
                            bindaddrs.each do |iface, addr|
                                bind_addr = addr
                                break
                            end
                        end 
                    end
                    if !bind_addr.nil?
                        break
                    end
                end
            else
                if node["network"]["interfaces"].has_key? bind_interface
                    bind_addr = node[:network][:interfaces][bind_interface][:addresses].find {|addr, addr_info| addr_info[:family] == "inet"}.first
                else
                    raise "Unable to find requested bind interface #{bind_interface} on #{node["ipaddress"]}"
                end
            end
            if bind_addr.nil?
                raise "Could not find bind address for node:#{node["ipaddress"]}. Using; bind-network:#{bind_network}, bind-interface#{bind_interface}"
            end
        end
    end
end
