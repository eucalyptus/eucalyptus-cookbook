### **eucadev** ➠ _tools for Eucalyptus developers and testers_

These tools allow one to deploy a Eucalyptus cloud—in a Vagrant-provisioned VM or in a cloud instance from AWS or Eucalyptus—with minimal effort. Currently, only single-node installations in virtual resources are supported, but we have plans to support multiple nodes, bare-metal provisioining, and more.



### Dev/test environment in a VirtualBox VM

This method produces a dev/test environment in a single virtual machine, with all Eucalyptus components deployed in it. By default, components will be built from latest source, which can be modified and immediately tested on the VM.  The source will be located on a 'synced folder' (`eucalyptus-src`), which can be edited on the host system but built on the guest system. Alternatively, you can install from latest packages, saving time.

1. Install [VirtualBox](https://www.virtualbox.org) (You may need to install kernel-headers and other packages to load the kernel module, look at this [blog post](http://www.if-not-true-then-false.com/2010/install-virtualbox-with-yum-on-fedora-centos-red-hat-rhel/) if you have problems.)

2. Install [Vagrant](http://www.vagrantup.com/) >= 1.5.2

3. Install [git](http://git-scm.com)

4. Install [ChefDK](https://downloads.chef.io/chef-dk/) 

5. Install vagrant plugins

        $ vagrant plugin install vagrant-berkshelf --plugin-version '>= 2.0.1'
        $ vagrant plugin install vagrant-omnibus

6. Check out [eucadev](https://github.com/eucalyptus/eucalyptus-cookbook/eucadev.md) (ideally [fork](http://help.github.com/fork-a-repo/) it and clone the fork to your local machine, so you can contribute):

        $ git clone https://github.com/eucalyptus/eucalyptus-cookbook.git

7. *Optionally:* Check the default parameters in `eucadev/Vagrantfile` and `eucadev/roles/cloud-in-a-box.json`
  * `install-type` is `"source"` by default. Set the value to `"packages"` for an RPM-based installation,  which can take less than half the time of a source install (e.g., 20 min instead of 48), but won't allow you to edit and re-deploy code easily.
  * In Vagrantfile, `memory` is 3GB (`3072`) by default. For a source-based install without a Web console, you may be able to get away with less, such as 1GB. Giving the VM more should improve performance.

8. Start the VM and wait for eucadev to install Eucalyptus in it (may take a long time, _20-60 min_ or more):

        $ cd eucadev; vagrant up
        
##### What now?

* If the test instance started successfully, you can try connecting to it via SSH:
  * Connect to the VM hosting the cloud: `$ vagrant ssh`
  * Become `root` to read the credentials: `$ sudo bash`
  * Source the Eucalyptus configuration file: `# source /root/eucarc`
  * Look up the IP of the running instnace: `# euca-describe-instances `
  * Connect to the instance from the VM: `# ssh -i /root/my-first-keypair cirros@PUBLIC-IP-OF-THE-INSTANCE`

* Connect to the Eucalyptus user console:
  * In a Web browser on your host, go to `http://localhost:8888`
  * Login with account=eucalyptus, user=admin, password=foobar
  
* Install [euca2ools](https://github.com/eucalyptus/euca2ools) on your host and control the cloud from the command line:

        $ source creds/eucarc
        $ euca-describe-instances 
        RESERVATION	r-49C1448D	539043227142	default
        INSTANCE	i-E4C54166	emi-34793865	192.168.192.102	1.0.217.179	running	my-first-keypair	0		m1.small	2013-12-05T23:11:59.118Z	cluster1	eki-58DF396F	eri-BB603B1C		        monitoring-disabled	192.168.192.102	1.0.217.179			instance-store					paravirtualized				
        TAG	instance	i-E4C54166	euca:node	10.0.2.15
        
  * **Note:** you won't be able to connect to cloud instances from your host, only from inside the VM.

* Make a change to the code and redeploy it:
  * Source code for Eucalyptus is located under `eucalyptus-src` (relative to `eucadev` directory on the host and relative to `/vagrant` on the guest). Before making changes to it, we recommend creating a new git branch (which you can later turn into a pull request if you decide to contribute your change back). You can do this either inside the VM or on the host:

                $ cd eucalyptus-src
                $ git checkout -b my-bug-fix

  * With your favorite C-language editor, change the Node Controller:
    * As an experiment, go ahead and change the string `"spawning Eucalyptus node controller"` in `node/handlers.c` to say `"spawning my own Eucalyptus node controller"`.
    * *Inside the VM*, rebuild, reinstall, and restart just the Node Controller:

                # cd node
                # make
                # make install
                # service eucalyptus-nc restart
       
    * Inside the VM, verify that your change took effect:
  
                # grep spawning /var/log/eucalyptus/nc.log 
                2014-01-27 22:07:37  INFO | spawning Eucalyptus node controller v3.4.2 [built 2014-01-27 21:44:07+00:00]
                2014-01-27 22:07:38  INFO | spawning monitoring thread
                2014-01-27 22:33:55  INFO | spawning my own Eucalyptus node controller v3.4.2 [built 2014-01-27 22:33:22+00:00]
                2014-01-27 22:33:55  INFO | spawning monitoring thread
  * With your favorite Java editor, change the Cloud Controller:
    * For serious work, you'll probably want to import the project into your IDE, such as IntelliJ or Eclipse. Pointing either one at the `eucalyptus-src` directory upon import and following prompts should get you to where the IDE can help you with syntax completion and compile errors. **Note:** do not try to build eucalyptus from the IDE unless you are on a Linux machine, though, as the system relies on Linux native bindings.

    * As an experiment, go ahead and change the string `"Creating Bootstrapper instance."` in `clc/modules/msgs/src/main/java/com/eucalyptus/bootstrap/SystemBootstrapper.java` to say `"Creating my own Bootstrapper instance."`.
    * *Inside the VM*, rebuild, reinstall, and restart just the Cloud Controller:

                # cd clc
                # make
                # make install
                # service eucalyptus-cloud restart
       
    * Inside the VM, verify that your change took effect:
  
                # grep "Creating my own" /var/log/eucalyptus/cloud-output.log 
                2014-01-27 23:05:24  INFO | Creating my own Bootstrapper instance.
                2014-01-27 23:05:52  INFO | Creating my own Bootstrapper instance.
  * **Note:** running `make install` from the root of the source tree will damage your installation because the configuration file will be overwritten by the default version.


##### VMware Fusion

**Caveat:** the following instructions aren't immediately applicable as the current `Vagrantfile` does not accommodate `vmware_fusion` provider. Stay tuned for further changes.

It is possible to run EucaDev on VMware Fusion via Vagrant. Currently, this requires that you purchase a license for the fusion plug-in from HashiCorp. Assuming you've purchased the license, install the plug-in and activate it.

        $ vagrant plugin install vagrant-vmware-fusion
        $ vagrant plugin license vagrant-vmware-fusion license.lic

You can use VMware Fusion Standard or Professional. In either case, you will need to _disable promiscuous mode authentication_:

  * In *Fusion Standard*, create a file via 

        $ sudo touch "/Library/Preferences/VMware Fusion/promiscAuthorized"
        
     and restart Fusion.
     
  * In *Fusion Profressional*, go to `Preferences` -> `Network` and uncheck the box that says `Require authentication to enter promiscious mode`.

When you move from one hypervisor to another while using the same EucaDev configuration, there may be a virtual network device on the host operating system that would have to be removed.

  * When switching from *VirtualBox*: go to `Preferences` -> `Network` -> `Host-Only Network` and remove devices (e.g., `vboxnet0`) for the EucaDev VM that you no longer wish to deploy with VirtualBox. In our experience, one also had to restart the network devices that VMware Fusion controls:

        $ sudo /Applications/VMware\ Fusion.app/Contents/Library/vmnet-cli --stop
        $ sudo /Applications/VMware\ Fusion.app/Contents/Library/vmnet-cli --start
        
  * When switching from *VMware Fusion*: go to `Preferences` -> `Network` and remove `vmnet2` under `Custom`.

### Dev/test environment in AWS or Eucalyptus

This method produces a dev/test environment in a single cloud instance, with all components deployed in it. (Yes, you can run a Eucalyptus cloud in a Eucalyptus cloud or run a Eucalyptus cloud in an Amazon cloud. _Inception!_) By default, components will be built from latest source, which can be modified and immediately tested on the VM.  Alternatively, you can install from latest packages, saving time.

1. Install [Vagrant](http://www.vagrantup.com/)

2. Install [git](http://git-scm.com)

3. Install vagrant plugins

        $ vagrant plugin install vagrant-berkshelf
        $ vagrant plugin install vagrant-omnibus
        $ vagrant plugin install vagrant-aws
        
4. Check out [eucadev](https://github.com/eucalyptus/eucalyptus-cookbook/eucadev.md) (ideally [fork](http://help.github.com/fork-a-repo/) it and clone the fork to your local machine, so you can contribute)

        $ git clone https://github.com/eucalyptus/eucalyptus-cookbook.git
        
5. Set the parameters in `eucadev/Vagrantfile` and, optionally, in `eucadev/roles/cloud-in-a-box.json`
  * `install-type` is `"source"` by default. Set the value to `"packages"` for an RPM-based installation,  which can take less than half the time of a source install (e.g., 20 min instead of 48), but won't allow you to edit and re-deploy code easily.
  * `aws.instance_type` is `m1.medium` by default. Consider whether this instance type has sufficient memory for your Eucalyptus cloud. For a source-based install without a Web console, you may be able to get away with 1GB, but we recommend 3GB for a typical installation. Selecting a beefier instance should improve performance.
  * Change the other variables to match the parameters of the cloud that you would like to use:

    ```     
    aws.access_key_id = "XXXXXXXXXXXXXXXXXX"
    aws.secret_access_key = "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"
    aws.instance_type = "m1.medium"
    ## This CentOS 6 EMI needs to have the following commented out of /etc/sudoers,
    ## Defaults    requiretty
    aws.ami = "emi-1873419A"
    aws.security_groups = ["default"]
    aws.region = "eucalyptus"
    aws.endpoint = "http://10.0.1.91:8773/services/Eucalyptus"
    aws.keypair_name = "vic"
    override.ssh.username ="root"
    override.ssh.private_key_path ="/Users/viglesias/.ssh/id_rsa"
    ```
6. Install a "dummy" vagrant box file to allow override of the box with the ami/emi:

        $ vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
        
7. Start the VM and wait for eucadev to install Eucalyptus in it (may take a long time, _20-60 min_ or more):
        
        $ cd eucadev; vagrant up --provider=aws
