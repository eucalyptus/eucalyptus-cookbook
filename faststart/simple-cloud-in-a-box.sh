#!/bin/bash -xe

# Simplest possible CIAB script. Assumes:
#   1. valid cookbooks in ./cookbooks directory;
#   2. valid nuke.json runlist;
#   3. valid ciab.json runlist.

# Get rid of old Chef stuff lying about.
rm -rf /var/chef/*

# Tar up the cookbooks for use by chef-solo.
tar czvf cookbooks.tgz cookbooks

# Run the nuke recipe, which gets rid of all traces of Euca.
chef-solo -r cookbooks.tgz -j nuke.json 1>/tmp/ciab.nuke.out

# Install Euca and start it up in the cloud-in-a-box configuration.
chef-solo -r cookbooks.tgz -j ciab.json 1>/tmp/ciab.install.out

# The one-liner version, for reference:
# chef-solo -r cookbooks.tgz -j nuke.json; rm -rf /var/chef/*;tar czvf cookbooks.tgz cookbooks; chef-solo -r cookbooks.tgz -j ciab.json

