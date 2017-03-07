[![Stories in Ready](https://badge.waffle.io/eucalyptus/eucalyptus-cookbook.png?label=ready&title=Ready)](https://waffle.io/eucalyptus/eucalyptus-cookbook)
eucalyptus Cookbook
===================
This cookbook installs and configures Eucalyptus on RHEL/CentOS 7 physical and virtual machines. Source and package installations are supported.

Requirements
------------

### Branches
The following table descirbes the branch to use for each Eucalyptus release:

| Branch       | Cookbook version | Euca version |Notes |
| ------------- |------------- | ------------- |------------- |
|master   | 0.3.x | 4.1.0 | maps to latest released eucalyptus version |
|euca-4.0 | 0.3.x| 4.0.2 |Stable branch for 4.0.x installs |
|euca-4.1 | 0.4.x | 4.1.1 | Maint branch for 4.1.x installs|
|euca-4.2 | 1.0.x | 4.2.0 |breaks the attribute API |
|euca-4.3 | 1.0.x | 4.3.0 |Stable branch for 4.3.x installs |
|euca-4.4 | 1.0.x | 4.4.0 |Stable branch for 4.4.x installs |

### Environment
To deploy a distributed topology it is necessary to define an environment with at least these attributes defined:
- node['eucalyptus']['topology']
- node['eucalyptus']['network']['config-json']

```
"default_attributes": {
    "eucalyptus": {
      "topology": {
        "clc-1": "10.111.5.163",
        "walrus": "10.111.5.163",
        "user-facing": ["10.111.5.163"],
        "clusters": {
          "default": {
            "cc-1": "10.111.5.164",
            "sc-1": "10.111.5.164",
            "storage-backend": "das",
            "das-device": "vg01",
            "nodes": "10.111.5.162 10.111.5.166 10.111.5.165 10.111.5.157"
          }
        }
      },
      "network": {
        "mode": "EDGE",
        "config-json": {
                  "InstanceDnsDomain" : "eucalyptus.internal",
                  "InstanceDnsServers": ["10.111.5.163"],
                  "PublicIps": ["10.111.55.1-10.111.55.220"],
                  "Subnets": [],
        "Clusters": [
           {
            "Name": "default",
            "MacPrefix": "d0:0d",
            "Subnet": {
                "Name": "172.16.55.0",
                "Subnet": "172.16.55.0",
                "Netmask": "255.255.255.0",
                "Gateway": "172.16.55.1"
            },
            "PrivateIps": [ "172.16.55.20-172.16.55.140"]
            }]
          }
        }
      }
    }  
```

#### Platforms
This cookbook only supports RHEL/CentOS 7 at the time being.

#### Berkshelf
A Berksfile is included to allow users to easily download the required cookbook dependencies.
- Install Berkshelf: `gem install berkshelf`
- Install Deps from inside this cookbook: `berks install`

#### Cookbooks
- `ntp` - sets up NTP for all Eucalyptus servers
- `yum` - used for managing repositories

#### Chef server config 
Ensure that the following config is set in `/etc/chef-server/chef-server.rb`:
erchef['s3_url_ttl'] = 3600

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
    <td><tt>maint-4.1</tt></td>
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
For cloud-in-a-box installs look at...
[Eucadev](https://github.com/eucalyptus/eucalyptus-cookbook/blob/master/eucadev.md)

For distributed topologies...
[Deployment with motherbrain](http://testingclouds.wordpress.com/2014/03/24/install-eucalyptus-4-0-using-motherbrain-and-chef/)

Faststart
-------------------
### Methodology
Faststart is a Bash script, `faststart/cloud-in-a-box.sh`, that invokes the Eucalyptus cookbook in order to install a single host cloud-in-a-box install. There is an HTTP redirect in place for hphelion.com/eucalyptus-install that points to that script in the faststart branch so that users can use the following to invoke it:

    bash <(curl -Ls hphelion.com/eucalyptus-install)

Once invoked the script does the following:

1. Checks for necessary resources on the machine that it is installing on (ie disk, memory, virtualization extensions)
2. Asks the user for the minimum necessary configuration parameters.
3. Installs the Chef client
4. Runs the Chef client in order to install Eucalyptus using the cookbook tarball and the inputs from the user.

Inputs from the user are searched and replaced into the templates in `faststart/ciab-template.json` and `fastart/node-template.json` and then used as follows to run the cookbook:

    chef-client -z -r cookbooks.tgz -j ciab.json

### Releasing
In order to release a new version of Faststart, you must first package up the current cookbook versions with Berkshelf.

1. Ensure Berkshelf is installed via the [ChefDK](https://downloads.chef.io/chef-dk/)
2. Change directories to where your eucalyptus-cookbook repo lives.
3. Run `berks package` to bundle all cookbook deps into a tarball, replacing VERSION with the desired release number, for example 4.2.0: `berks package eucalyptus-cookbooks-$VERSION.tgz`
4. Upload the tarball to S3 in the euca-chef bucket, then make the object publicly readable. To test this, simply try to download the file via its URL, by using your browser. An example URL is http://euca-chef.s3.amazonaws.com/eucalyptus-cookbooks-$VERSION.tgz
5. Change the $cookbooks_url variable in faststart/cloud-in-a-box.sh to point to your new publicly available tarball.
6. Commit and push that change to the branch for this release, for example euca-4.2.
7. In order to push the change live, merge the branch into faststart.

Contributing
------------

1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
Authors:

Vic Iglesias <vic.iglesias@eucalyptus.com>
