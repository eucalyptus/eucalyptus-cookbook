#!/bin/bash -xe

#chef-solo -r new-cookbooks.tgz -j nuke.json
chef-solo -j nuke.json

