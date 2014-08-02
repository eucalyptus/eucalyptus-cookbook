#
## Cookbook Name:: eucalyptus
## Recipe:: install-source
##
##Copyright [2014] [Eucalyptus Systems]
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
execute "echo \"export PATH=$PATH:#{node['eucalyptus']['home-directory']}/usr/sbin/\" >>/root/.bashrc"

execute "export JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk.x86_64' && export JAVA='$JAVA_HOME/jre/bin/java' && export EUCALYPTUS='#{node["eucalyptus"]["home-directory"]}' && make && make install" do
  cwd "#{node["eucalyptus"]["source-directory"]}/"
  creates "/etc/init.d/eucalyptus-cloud"
  timeout node["eucalyptus"]["compile-timeout"]
end

tools_dir = "#{node["eucalyptus"]["source-directory"]}/tools"
if node['eucalyptus']['source-repo'].end_with?("internal")
  tools_dir = "#{node["eucalyptus"]["source-directory"]}/eucalyptus/tools"
end

%w{eucalyptus-cloud eucalyptus-cc eucalyptus-nc}.each do |init_script|
  execute "ln -sf #{tools_dir}/eucalyptus-cloud /etc/init.d/#{init_script}" do
    creates "/etc/init.d/#{init_script}"
  end
  execute "chmod +x #{tools_dir}/eucalyptus-cloud"
end

if node["eucalyptus"]["network"]["mode"] == "EDGE"
  execute "ln -fs #{tools_dir}/eucanetd /etc/init.d/eucanetd"
  execute "chmod +x #{tools_dir}/eucanetd"
end

execute "Copy Policy Kit file for NC" do
  execute "cp #{tools_dir}/eucalyptus-nc-libvirt.pkla /var/lib/polkit-1/localauthority/10-vendor.d/"
end

execute "#{node["eucalyptus"]["home-directory"]}/usr/sbin/euca_conf --setup -d #{node["eucalyptus"]["home-directory"]}"
