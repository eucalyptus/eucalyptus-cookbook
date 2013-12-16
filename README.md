eucalyptus Cookbook
===================
This cookbook installs and configures Eucalyptus on CentOS 6 physical and virtual machines. Source and package installations are supported.

Requirements
------------

#### Platforms
This playbook only supports RHEL/CentOS 6 at the time being.

#### Cookbooks
- `bridger` - configures bridges on Node Controllers
- `ntp` - sets up NTP for all Eucalyptus servers
- `partial_search` - required for `ssh_known_hosts`
- `ssh_known_hosts` - add components to known hosts list
- `yum` - used for managing repositories
- `selinux` - disables selinux on Eucalyptus servers

Attributes
----------
Attribute list can be found in attributes/default.rb

Some common attributes are:
#### eucalyptus installation config
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>["eucalyptus"]["install-type"]</tt></td>
    <td>String</td>
    <td>Choose to install from `package` or `source`</td>
    <td><tt>package</tt></td>
  </tr>
  <tr>
    <td><tt>["eucalyptus"]["source-repo"]</tt></td>
    <td>String</td>
    <td>Git repository to clone when building from source</td>
    <td><tt>https://github.com/eucalyptus/eucalyptus.git</tt></td>
  </tr>
  <tr>
    <td><tt>["eucalyptus"]["source-branch"]</tt></td>
    <td>String</td>
    <td>Branch to use when building from source</td>
    <td><tt>testing</tt></td>
  </tr>
</table>

#### eucalyptus network config
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>["eucalyptus"]["network"]["mode"]</tt></td>
    <td>String</td>
    <td>Networking mode to use</td>
    <td><tt>MANAGED-NOVLAN</tt></td>
  </tr>
  <tr>
    <td><tt>["eucalyptus"]["network"]["private-interface"]</tt></td>
    <td>String</td>
    <td>Private interface of component</td>
    <td><tt>eth0</tt></td>
  </tr>
  <tr>
    <td><tt>["eucalyptus"]["network"]["public-interface"]</tt></td>
    <td>String</td>
    <td>Public interface of component</td>
    <td><tt>eth0</tt></td>
  </tr>
  <tr>
    <td><tt>["eucalyptus"]["network"]["bridge-interface"]</tt></td>
    <td>String</td>
    <td>Bridge interface of component. Will be created and set by playbook</td>
    <td><tt>br0</tt></td>
  </tr>
</table>


Usage
-----
#### eucalyptus from packages

For a single frontend configuration use a role similar to:

```json
{
  "name": "cloud-controller",
  "description": "",
  "json_class": "Chef::Role",
  "default_attributes": {
    "eucalyptus": {
      "install-load-balancer": false
    }
  },
  "override_attributes": {
  },
  "chef_type": "role",
  "run_list": [
    "recipe[eucalyptus]",
    "recipe[eucalyptus::eutester]",
    "recipe[eucalyptus::cluster-controller]",
    "recipe[eucalyptus::walrus]",
    "recipe[eucalyptus::storage-controller]",
    "recipe[eucalyptus::cloud-controller]",
    "recipe[eucalyptus::register-components]"
  ],
  "env_run_lists": {
  }
}
```


For a source build use something like:
```json
{
  "name": "cloud-controller-source",
  "description": "",
  "json_class": "Chef::Role",
  "default_attributes": {
    "eucalyptus": {
      "install-type": "source",
      "release-rpm": "http://release-repo.eucalyptus-systems.com/releases/eucalyptus/3.4/centos/6/x86_64/eucalyptus-release-internal-3.4-1.el6.noarch.rpm",
      "install-load-balancer": false
    }
  },
  "override_attributes": {
  },
  "chef_type": "role",
  "run_list": [
    "recipe[eucalyptus]",
    "recipe[eucalyptus::eutester]",
    "recipe[eucalyptus::cloud-controller]"
  ],
  "env_run_lists": {
  }
}
```

Contributing
------------
TODO: (optional) If this is a public cookbook, detail the process for contributing. If this is a private cookbook, remove this section.

e.g.
1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
Authors: TODO: List authors
