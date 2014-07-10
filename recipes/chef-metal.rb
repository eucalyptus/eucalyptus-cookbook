require 'chef_metal_fog'

key_pair = 'vic2'
chef_env = "vic-1"
cluster_config = { "storage-backend" => 'overlay' }
global_config = { "eucalyptus" => { "install-load-balancer" => false, 
                             "install-imaging-worker" => false } }

with_driver 'fog:AWS'
with_chef_server "https://new-qa.qa1.eucalyptus-systems.com",
  :client_name => "viglesias",
  :signing_key_filename => "/Users/viglesias/.chef/viglesias.pem"
with_machine_options ssh_username: 'root', :bootstrap_options => {
    :image_id => 'emi-A6021FA7',
    :flavor_id => 'm2.2xlarge',
    :key_name => key_pair,
#    :block_device_mapping => [
#    { 'DeviceName' => '/dev/sda', 'Ebs.VolumeSize' => '10' }],
    :user_data => <<eos
#!/bin/bash
ephemeral=/dev/vdb
dir=/var/lib/eucalyptus
mkdir -p $dir
mkfs.ext4 -F $ephemeral
mount $ephemeral $dir
eos
  }

chef_environment chef_env do
  default_attributes global_config
end

with_chef_environment chef_env

auto_batch_machines = false

fog_key_pair key_pair do
  allow_overwrite true
end

### Provision and allocate nodes upfront
machine_batch "Provision components" do
  machine "CLC" do
    recipe "eucalyptus::cloud-controller"
    recipe "eucalyptus::walrus"
    recipe "eucalyptus::user-facing"
  end
  machine "CC" do
    recipe "eucalyptus::cluster-controller"
    recipe "eucalyptus::storage-controller"
  end
  machine "NC-1" do
    recipe "eucalyptus::node-controller"
    attributes(
    eucalyptus: {
      'nc' => {'work-size' => 50000}
    }
  )
  end
end

ruby_block "Fill in topology" do
  block do
    env_search = "chef_environment:#{chef_env}"
    clc_recipe_search = "recipe:\"eucalyptus\\:\\:cloud-controller\""
    clc_node = Chef::Search::Query.new.search(:node, env_search + " AND " + clc_recipe_search).first.first
    Chef::Log.info "CLC: #{clc_node.attributes[:ipaddress]}"

    walrus_recipe_search = "recipe:\"eucalyptus\\:\\:walrus\""
    walrus_node = Chef::Search::Query.new.search(:node, env_search + " AND " + walrus_recipe_search).first.first
    Chef::Log.info "Walrus: #{walrus_node.attributes[:ipaddress]}"

    user_facing_recipe_search = "recipe:\"eucalyptus\\:\\:user-facing\""
    user_facing_nodes = Chef::Search::Query.new.search(:node, env_search + " AND " + user_facing_recipe_search).first
    user_facing_ips = []
    user_facing_nodes.each do |user_facing|
      user_facing_ips << user_facing.attributes[:ipaddress]
      Chef::Log.info "User facing: #{user_facing.attributes[:ipaddress]}"
    end

    global_config["eucalyptus"]["topology"] = { "clc-1" => clc_node.attributes[:ipaddress],
                                         "walrus" => walrus_node.attributes[:ipaddress],
                                         "user-facing" => user_facing_ips,
                                         "clusters" => {}
                                       }    

    cc_recipe_search = "recipe:\"eucalyptus\\:\\:cluster-controller\""
    cc_nodes = Chef::Search::Query.new.search(:node, env_search + " AND " + cc_recipe_search).first
    cc_nodes.each do |cc_node|
      Chef::Log.info "Cluster: #{cc_node.attributes[:ipaddress]}"
      cluster_name = cc_node.attributes["eucalyptus"]["local-cluster-name"]
      Chef::Log.info "Cluster name: #{cluster_name}"
      cluster_search = "eucalyptus_local-cluster-name:#{cluster_name}"
      sc_recipe_search = "recipe:\"eucalyptus\\:\\:storage-controller\""
      sc_node = Chef::Search::Query.new.search(:node, env_search + " AND " + sc_recipe_search + " AND " + cluster_search).first.first
      Chef::Log.info "Storage Controller: #{sc_node.attributes[:ipaddress]}"
      nc_recipe_search = "recipe:\"eucalyptus\\:\\:node-controller\""
      nc_nodes = Chef::Search::Query.new.search(:node, env_search + " AND " + nc_recipe_search + " AND " + cluster_search).first
      nc_list = []
      nc_nodes.each do |nc_node|
        Chef::Log.info "Node Controller: #{nc_node.attributes[:ipaddress]}"
        nc_list << nc_node.attributes[:ipaddress]
      end
      global_config["eucalyptus"]["topology"]["clusters"][cluster_name] = { "cc-1" => cc_node.attributes[:ipaddress],
                                                                     "sc-1" => sc_node.attributes[:ipaddress],  
                                                                     "nodes" => nc_list.join(",")}
      global_config["eucalyptus"]["topology"]["clusters"][cluster_name].merge(cluster_config)
    end 
  end
end

chef_environment chef_env do
  default_attributes global_config
end

machine_batch "Register components" do
  machine "CLC" do
    recipe "eucalyptus::register-components"
  end
end

machine_batch "Sync Keys" do
  %w{CC NC-1}.each do |cloud_component|
    machine cloud_component do
      recipe "eucalyptus::sync-keys"
    end
  end
end

machine_batch "Configure" do
  machine "CLC" do
    recipe "eucalyptus::configure"
  end
end
