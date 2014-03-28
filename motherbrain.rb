# This is an example motherbrain plugin.
#
# To see a list of all commands this plugin provides, run:
#
#   mb eucalyptus help
#
# For documentation, visit https://github.com/RiotGames/motherbrain

# When bootstrapping a cluster for the first time, you'll need to specify which
# components and groups you want to bootstrap.
stack_order do
  bootstrap 'cloud-controller::default'
  bootstrap 'user-facing::default'
  bootstrap 'walrus::default'
  bootstrap 'user-console::default'
  bootstrap 'cluster-controller::default'
  bootstrap 'storage-controller::default'
  bootstrap 'cloud-controller::configure-storage'
  bootstrap 'node::default'
  bootstrap 'nuke::default'
end

component 'cloud-controller' do
  description "Eucalyptus Cloud Controller"
  versioned_with 'eucalyptus.version'
  group 'default' do
    recipe 'eucalyptus::cloud-controller'
    recipe 'eucalyptus::register-components'
  end
  group 'configure-storage' do
    recipe 'eucalyptus::configure-storage'
  end
end

component 'user-facing' do
  description "Eucalyptus User Facing Services"
  versioned_with 'eucalyptus.version'
  group 'default' do
    recipe 'eucalyptus::facing'
  end
end

component 'walrus' do
  description "Eucalyptus Walrus Backend"
  versioned_with 'eucalyptus.version'
  group 'default' do
    recipe 'eucalyptus::walrus'
  end
end

component 'cluster-controller' do
  description "Eucalyptus Cluster Controller"
  versioned_with 'eucalyptus.version'
  group 'default' do
    recipe 'eucalyptus::cluster-controller'
    recipe 'eucalyptus::register-nodes'
  end
end

component 'storage-controller' do
  description "Eucalyptus Storage Controller"
  versioned_with 'eucalyptus.version'
  group 'default' do
    recipe 'eucalyptus::storage-controller'
  end
end

component 'node' do
  description "Node Controller"
  versioned
  group 'default' do
    recipe 'eucalyptus::node-controller'
  end
end

component 'user-console' do
  description "Eucalyptus User Console"
  versioned
  group 'default' do
    recipe 'eucalyptus::user-console'
  end
end

component 'nuke' do
  description "The nuclear option"
  versioned
  group 'default' do
    recipe 'eucalyptus::nuke'
  end
end
