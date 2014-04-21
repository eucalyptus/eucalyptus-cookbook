#!/bin/bash
# 
# This script runs inside the Vagrant-provisioned VM 
# after eucalyptus-cookbook has installed and configured 
# Eucalyptus. The intention of the script is to make
# changes that are specific to EucaDev-based deployments 
# and are not general enough to be part of the cookbook.

#
# Make cloud admin credentials available on the host
#
mkdir -p /vagrant/creds # ensure the directory exists on first run
rm -rf /vagrant/creds/* # blow away creds from previous runs
for FILE in eucarc iamrc jssecacerts *.pem
do 
	cp /root/$FILE /vagrant/creds/ # make copy
done
sed --in-place 's#://[^:]\+:#://127.0.0.1:#g' /vagrant/creds/eucarc # external copy should point to localhost
source /root/eucarc
euare-useraddloginprofile -u admin -p foobar
