#!/bin/bash
#
# This script runs inside the Vagrant-provisioned VM
# before eucalyptus-cookbook installs and configures
# Eucalyptus. The intention of the script is to make
# changes that are specific to EucaDev-based deployments
# and are not general enough to be part of the cookbook.

#
# Create the directory for Eucalyptus to be shared with VM.
#
rm -rf /vagrant/eucalyptus-src
mkdir -p /vagrant/eucalyptus-src

#
# Bump up Yum and Git timeouts, which cause failures
# when running on slow machines and unreliable networks
#
echo "timeout=300" >> /etc/yum.conf
yum install -y git
git config --global http.postBuffer 524288000

#
# Bump up the OS limits so that CLC won't exceed them
# on distros with conservative defaults.
#
echo "* soft nproc 64000" >>/etc/security/limits.conf
echo "* hard nproc 64000" >>/etc/security/limits.conf
rm /etc/security/limits.d/90-nproc.conf # these apparently override limits.conf?

#
# Use ebtables to prevent traffic from leaving the
# VM on the second NIC. (Otherwise, DHCP server provided
# by VirtualBox will respond to requests from Eucalyptus
# VMs, which may make VMs inaccessible.)
#
yum install -y ebtables
ebtables -I FORWARD -o eth1 -j DROP
ebtables -I OUTPUT -o eth1 -j DROP
/etc/init.d/ebtables save
chkconfig --level 345 ebtables on
