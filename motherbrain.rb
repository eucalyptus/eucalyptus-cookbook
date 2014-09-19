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
  bootstrap 'cloud::full'
  bootstrap 'cloud::default'
  bootstrap 'cloud::frontend'
  bootstrap 'cluster::default'
  bootstrap 'cluster::cluster-controller'
  bootstrap 'cluster::storage-controller'
  bootstrap 'cloud::user-facing'
  bootstrap 'cloud::walrus'
  bootstrap 'cloud::user-console'
  bootstrap 'node::default'
  bootstrap 'midokura::all-in-one'
  bootstrap 'midokura::midokura-cp'
  bootstrap 'midokura::midokura-api'
  bootstrap 'midokura::midolman'
  bootstrap 'midokura::zookeeper'
  bootstrap 'cloud::configure'
  bootstrap 'cloud::create-first-resources'
  bootstrap 'nuke::default'
end

component 'cloud' do
  description "Eucalyptus Cloud Controller"
  versioned_with 'eucalyptus.version'
  group 'default' do
    recipe 'eucalyptus::cloud-controller'
    recipe 'eucalyptus::register-components'
  end
  group 'frontend' do
    recipe 'eucalyptus::cloud-controller'
    recipe 'eucalyptus::register-components'
    recipe 'eucalyptus::walrus'
    recipe 'eucalyptus::user-console'
  end
  group 'walrus' do
    recipe 'eucalyptus::walrus'
  end
  group 'user-facing' do
    recipe 'eucalyptus::user-facing'
  end
  group 'user-console' do
    recipe 'eucalyptus::user-console'
  end
  group 'full' do
    recipe 'eucalyptus::cloud-controller'
    recipe 'eucalyptus::user-console'
    recipe 'eucalyptus::register-components'
    recipe 'eucalyptus::walrus'
    recipe 'eucalyptus::cluster-controller'
    recipe 'eucalyptus::storage-controller'
  end
  group 'configure' do
    recipe 'eucalyptus::configure'
  end
  group 'create-first-resources' do
    recipe 'eucalyptus::create-first-resources'
  end
end

component 'cluster' do
  description "Eucalyptus Cluster Controller"
  versioned_with 'eucalyptus.version'
  group 'default' do
    recipe 'eucalyptus::cluster-controller'
    recipe 'eucalyptus::storage-controller'
  end
  group 'cluster-controller' do
    recipe 'eucalyptus::cluster-controller'
  end
  group 'storage-controller' do
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

component 'nuke' do
  description "The nuclear option"
  versioned
  group 'default' do
    recipe 'eucalyptus::nuke'
  end
end

component 'midokura' do
  description "Midonet installation"
  versioned
  group 'all-in-one' do
    recipe 'midokura::default'
  end
  group 'midolman' do
    recipe 'midokura::midolman'
  end
  group 'midokura-api' do
    recipe 'midokura::midokura-api'
  end
  group 'midokura-cp' do
    recipe 'midokura::midokura-cp'
  end
  group 'zookeeper' do
    recipe 'midokura::zookeeper'
  end
end
