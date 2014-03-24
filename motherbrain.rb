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
  bootstrap 'frontend::default'
  bootstrap 'user-console::default'
  bootstrap 'cluster::default'
  bootstrap 'frontend::configure-storage'
  bootstrap 'frontend::full'
  bootstrap 'node::default'
  bootstrap 'nuke::default'
end

# Components are logical parts of your application. For instance, a web app
# might have "web" and "database" components.
component 'frontend' do
  # Replace this with a better description for the component.
  description "Eucalyptus Cloud Controller and Walrus"

  # You can signify that a component's version is mapped to an environment
  # attribute, and then change the version with:
  #
  #   mb eucalyptus upgrade --components app:1.2.3
  #
  versioned # This defaults to 'app.version'
  # You can also specify a custom attribute.
  # versioned_with 'eucalyptus.version'

  # Groups are collections of nodes linked by a search. If you only have one
  # group per component, it's typical to use "default" as the group name.  An
  # example of multiple groups would be a "database" component, with "master"
  # and "slave" groupds.
  group 'default' do
    recipe 'eucalyptus::cloud-controller'
    recipe 'eucalyptus::walrus'
    recipe 'eucalyptus::register-components'
    # In addition to recipes, you can also search by roles and attributes:
    # role 'web_server'
    # chef_attribute 'db_master', true
  end
  group 'register' do
    recipe 'eucalyptus::register-components'
  end
  group 'configure-storage' do
   recipe 'eucalyptus::configure-storage'
  end
  group 'full' do
    recipe 'eucalyptus::cloud-controller'
    recipe 'eucalyptus::register-components'
    recipe 'eucalyptus::cluster-controller'
    recipe 'eucalyptus::register-nodes'
    recipe 'eucalyptus::walrus'
    recipe 'eucalyptus::storage-controller'
    recipe 'eucalyptus::configure-storage'
  end
end

component 'cluster' do
  description "Cluster and Storage Controller"
  versioned
  group 'default' do
    recipe 'eucalyptus::cluster-controller'
    recipe 'eucalyptus::storage-controller' 
    recipe 'eucalyptus::register-nodes'
  end
  group 'cluster-controller' do
    recipe 'eucalyptus::cluster-controller'
  end
  group 'storage-controller' do
    recipe 'eucalyptus::storage-controller'
  end
  group 'register' do
    recipe 'eucalyptus::register-nodes'
  end
end

component 'node' do
  description "Node Controller"
  versioned
  group 'default' do
    recipe 'eucalyptus::node-controller'
  end
end
