# -*- mode: ruby -*-
# vi: set ft=ruby :
options = {
  :cores => 2,
  :memory => 3072,
}
Vagrant.configure("2") do |config|
    config.omnibus.chef_version = :latest
    config.berkshelf.enabled = true
    config.vm.provision "shell", path: "eucadev/prep.sh"
    config.vm.synced_folder ".", "/vagrant", owner: "root", group: "root"
    config.vm.provision :chef_solo do |chef|
      chef.roles_path = "roles"
      chef.add_role "cloud-in-a-box"  
      chef.json = { "eucalyptus" => { ## Choose whether to compile binaries from "source" or "packages"
                                      "install-type" => "packages",
                                      ## Does not change package version, use "eucalyptus-repo" variable
                                      "source-branch" => "testing",
                                      "eucalyptus-repo" => "http://downloads.eucalyptus.com/software/eucalyptus/nightly/4.0/centos/6/x86_64/",
                                      "euca2ools-repo" =>  "http://downloads.eucalyptus.com/software/euca2ools/nightly/3.1/centos/6/x86_64/",
                                      "yum-options" => "--nogpg",
                                      "default-img-url" => "http://euca-vagrant.s3.amazonaws.com/cirrosraw.img",
                                      "source-directory" => "/vagrant/eucalyptus-src",
                                      "install-load-balancer" => false,
                                      "install-imaging-worker" => false,
                                      "nc" => {"hypervisor" => "qemu", "work-size" => "50000"},
                                      "topology" => {  "clc-1" => "192.168.192.101", "walrus" => "192.168.192.101", 
                                                       "user-facing" => "192.168.192.101",
                                                       "clusters" => {"default" => { "storage-backend" => "overlay ",
                                                                                     "cc-1" => "192.168.192.101",
                                                                                     "sc-1" => "192.168.192.101",
                                                                                     "nodes" => "192.168.192.101"}
                                                          }
                                               },
                                       "network" => {  "mode" => "EDGE",
                                                       "public-interface" => "br0",
                                                       "private-interface" => "br0",
                                                       "bridged-nic" => "eth1",
                                                       "bridge-ip" => "192.168.192.101",
                                                       "config-json" => { "InstanceDnsServers" => ["192.168.192.101"],
                                                                          "PublicIps" => ["192.168.192.110-192.168.192.160"],
                                                                          "Clusters" => [{ "Name" => "default",
                                                                                           "Subnet" => {
                                                                                               "Name" => "192.168.192.0",
                                                                                               "Subnet" => "192.168.192.0",
                                                                                               "Netmask" => "255.255.255.0",
                                                                                               "Gateway" => "192.168.192.101"
                                                                                        },
                                                                                        "PrivateIps" => [ "192.168.192.10-192.168.192.80"]
                                                                                     }]}
                                                  }
                                      }}
    end
    config.vm.provision "shell", path: "eucadev/post.sh"
    config.vm.define "eucadev-all" do |u|
      u.vm.hostname = "eucadev-all"
      u.vm.box = "euca-deps"
      u.vm.box_url = "http://euca-vagrant.s3.amazonaws.com/euca-deps-virtualbox.box"
      u.vm.network :forwarded_port, guest: 8888, host: 8888
      u.vm.network :forwarded_port, guest: 8773, host: 8773
      u.vm.network :forwarded_port, guest: 8774, host: 8774
      u.vm.network :forwarded_port, guest: 8775, host: 8775
      u.vm.network :private_network, ip: "192.168.192.101"
      u.vm.provider :virtualbox do |v|
        v.customize ["modifyvm", :id, "--memory", options[:memory].to_i]
      	v.customize ["modifyvm", :id, "--cpus", options[:cores].to_i]
      end
      u.vm.provider :vmware_fusion do |v, override|
        override.vm.box_url = "http://euca-vagrant.s3.amazonaws.com/euca-deps-vmware.box"
        v.vmx["memsize"] = options[:memory].to_i
        v.vmx["numvcpus"] = options[:cores].to_i
        v.vmx["vhv.enable"] = "true"
      end
      u.vm.provider :aws do |aws, override|
        override.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
        override.ssh.pty = true
	aws.access_key_id = "AKIAJTSHR3GPTBCT4C3A"
        aws.secret_access_key = "ODExo3sPp/7mdyrQvBA5IkVqutkB19QIzPrxnRgd"
        aws.instance_type = "m1.medium"
        aws.keypair_name = "vic"
        aws.ami = "ami-8997afe0"
        override.ssh.username ="root"
        # Optional
        #aws.region = "eucalyptus"
        #aws.endpoint = "http://EUCALYPTUS_CLC_IP:8773/services/Eucalyptus"
        override.ssh.private_key_path ="~/.ssh/id_rsa"
        aws.instance_ready_timeout = 480
        aws.tags = {
                Name: "EucaDev",
        } 
     end
  end
end
