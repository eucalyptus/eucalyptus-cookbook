#!/bin/bash
# 
# This script runs inside the Vagrant-provisioned VM 
# after eucalyptus-cookbook has installed and configured 
# Eucalyptus. The intention of the script is to make
# changes that are specific to EucaDev-based deployments 
# and are not general enough to be part of the cookbook.

euare-useraddloginprofile -u admin -p foobar

echo "Your Eucalyptus development cloud installation is now complete!"

