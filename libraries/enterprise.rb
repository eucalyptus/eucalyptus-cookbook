#
# Cookbook Name:: eucalyptus
# Library:: enterprise
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
  module Enterprise
    @oss_backends = ['overlay', 'das', 'ceph-rbd']
    @enterprise_backends = ['equallogic', 'netapp', 'emc-vnx', 'threepar']

    def self.is_san?(node)
      if node['eucalyptus']['topology']
        clusters = node['eucalyptus']['topology']['clusters']
      else
        return false
      end
      clusters.each do |name, info|
        if @enterprise_backends.include? info['storage-backend']
          return true
        end
      end
      return false
    end

    def self.is_enterprise?(node)
      return self.is_san?(node)
    end
  end
end
