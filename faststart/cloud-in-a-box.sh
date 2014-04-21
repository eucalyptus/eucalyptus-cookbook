#!/bin/bash -xe
# Retrieved from:
# https://raw2.github.com/eucalyptus/eucadev/master/cloud_in_a_box.sh

# This script is for installing cloud-in-a-box. Documentation coming soon.

# TODO: make sure to check eth0 or em1 to pick the right interface for ciab.json
# TODO: check to make sure that EL 6.5 is in /etc/redhat-config
# TODO: make sure that virtualization is enabled

# Ignore the following bits; we're hardcoding in the ciab.json file locally for now.
#if [ -z "$publicips" ];then
    # public IPs aren't set; prompt for them.
#    echo "Enter the available range of public IP addresses for your cloud, in the following format:"
#    echo "  xxx.xxx.xxx.xxx-yyy.yyy.yyy.yyy"
#    echo "  (Example: 192.168.1.100-192.168.1.199)"
#    read -t 30 publicips
#    if [ "$?" -gt 0 ] ; then
#        echo "Timeout waiting for IP address range"
#        exit 1
#    fi
#else
#    echo "Using Public IPs: $publicips"
#fi

# Quick and dirty hack to install new euca2ools client needed by 4.0.0
# TODO: set euca2ools repo... in which recipe? 
#   See: https://github.com/eucalyptus/eucadev/blob/master/Vagrantfile#L21
# rpm -Uvh http://downloads.eucalyptus.com/software/euca2ools/nightly/3.1/centos/6/i386/python-requestbuilder-0.2.0-0.3.pre1.el6.noarch.rpm
# rpm -Uvh http://downloads.eucalyptus.com/software/euca2ools/nightly/3.1/centos/6/i386/euca2ools-3.1.0-0.0.164.20140321git697a0826.el6.noarch.rpm 

# remove old Chef recipes
rm -rf /var/chef/*

echo "Installing Chef"
curl -L https://www.opscode.com/chef/install.sh | bash > chef-install.log

### Download artifacts
if [ -z "$role" ];then
    export role=ciab
fi
echo "Using Role: $role"

# OK, we really should be pulling the latest recipes from 4.0 every time.
# Thus, we'll go ahead and pull these, and then rebuild the cookbooks file
# so we're getting the latest cookbook every time.

curl http://euca-chef.s3.amazonaws.com/cookbooks.tgz > COOKBOOK-DIRS/cookbooks.tgz
cd COOKBOOK-DIRS
wget https://github.com/eucalyptus/eucalyptus-cookbook/archive/master.zip 
mv master.zip euca-cookbook.zip
unzip -o euca-cookbook.zip
gunzip cookbooks.tgz
tar -xvf cookbooks.tar
rm -rf cookbooks/old-eucalyptus
mv cookbooks/eucalyptus cookbooks/old-eucalyptus
mv eucalyptus-cookbook-master cookbooks/eucalyptus
tar -cvf new-cookbooks.tar cookbooks
gzip new-cookbooks.tar
mv new-cookbooks.tar.gz ../new-cookbooks.tgz
cd ..

pwd

# Comment the next line out and replace it with the line after; we're changing
# the CIAB role to use 4.0 packages instead of 3.4.
# TODO: replace with the right CIAB.json file when it's done
# curl http://euca-chef.s3.amazonaws.com/ciab.json > $role.json

# For now, we're not even downloading; we're just hacking the local copy and using it.
#curl https://raw.githubusercontent.com/gregdek/fasterstart/master/ciab.json > $role.json
#sed -i "s/PUBLICIPS/$publicips/g" $role.json
#if [ ! -z "$bridge" ];then
#    sed -i "s/eth0/$bridge/g" $role.json
#fi

echo "Triple checking the right json file:"
cat $role.json

exit

# Comment out the next line using cookbooks.tgz and use the new-cookbooks.tgz instead.
# chef-solo -r cookbooks.tgz -j $role.json
chef-solo -r new-cookbooks.tgz -j $role.json 1>/tmp/chef-solo.out 2>/tmp/chef-solo.err
# chef-solo -j $role.json 
# chef-solo -j $role.json 1>/tmp/chef-solo.out 2>/tmp/chef-solo.err

# Add tip of the day to Eucalyptus console
# export UUID=`uuidgen` && sed -i "s|</body>|<iframe width=\"0\" height=\"0\" src=\"https://www.eucalyptus.com/docs/tipoftheday.html?${UUID}\" seamless=\"seamless\" frameborder=\"0\"></iframe></body>|" /usr/share/eucalyptus-console/static/index.html
