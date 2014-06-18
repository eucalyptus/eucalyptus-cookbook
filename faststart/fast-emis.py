# Software License Agreement (BSD License)
#
# Copyright (c) 2009-2014, Eucalyptus Systems, Inc.
# All rights reserved.
#
# Redistribution and use of this software in source and binary forms, with or
# without modification, are permitted provided that the following conditions
# are met:
#
#   Redistributions of source code must retain the above
#   copyright notice, this list of conditions and the
#   following disclaimer.
#
#   Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the
#   following disclaimer in the documentation and/or other
#   materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Author: Vic Iglesias vic.iglesias@eucalyptus.com
#
import json
from subprocess import call, Popen, PIPE
import urllib
import sys

import euca2ools

catalog_url = "http://emis.eucalyptus.com/catalog-web"
temp_dir_prefix = "emis"
menu = """1) Install an image
2) Exit
"""


def get_input():
    print menu
    return raw_input("Enter your selection: ").strip()

def check_output(command):
    process = Popen(command.split(), stdout=PIPE)
    return process.communicate()

def check_dependencies():
    ### Check that euca2ools 3.1.0 is installed and creds are sourced
    if call(["which", "euca-version"]):
        print "Euca2ools not found. Instructions can be found here:"
        print "https://www.eucalyptus.com/docs/eucalyptus/4.0/index.html#shared/installing_euca2ools.html"
        sys.exit(1)
    (major, minor, patch) = euca2ools.__version__.split('-')[0].split('.')
    if int(major) < 3 or (int(major) >= 3 and int(minor) < 1):
        print "Euca2ools version 3.1.0 or newer required."
        sys.exit(1)

def get_catalog():
    return json.loads(urllib.urlopen(catalog_url).read())["images"]


def get_image(number):
    return get_catalog()[number]


def print_catalog():
    catalog = get_catalog()
    format_spec = '{0:3} {1:20} {2:20} {3:20}'
    print format_spec.format("id", "version", "created-date", "description")
    image_number = 1
    for image in catalog:
        print format_spec.format(str(image_number), image["version"],
                                 image["created-date"], image["description"])
        image_number += 1
    print


def install_image():
    number = 0
    image = None
    while number == 0 or not image:
        try:
            number = int(raw_input("Enter the image ID you "
                                   "would like to install: "))
            image = get_image(number - 1)
        except (ValueError, KeyError, IndexError):
            print "Invalid image selected"
    image_name = image["os"] + "-" + image["created-date"]
    directory_format = '{0}-{1}.XXXXXXXX'.format(temp_dir_prefix, image["os"])

    ### Make temp directory
    (tmpdir, stderr) = check_output('mktemp -d ' + directory_format)

    ### Download image
    download_path = tmpdir.strip() + "/" + image_name + ".raw.xz"
    print "Downloading image to: " + download_path
    if call(["curl", image["url"], "-o", download_path]):
        print "Image download failed attempting to download: "
        print image["url"]
        sys.exit(1)

    print "Decompressing image..."
    if call(["xz", "-d", download_path]):
        print "Unable to decompress image downloaded to: "
        print download_path
        sys.exit(1)

    image_path = download_path.strip(".xz")
    install_cmd = "euca-install-image -r x86_64 -i {0} --virt hvm -b {1} -n {1}".format(image_path, image_name)
    print "Running installation command: "
    print install_cmd
    if call(install_cmd.split()):
        print "Unable to install image that was downloaded to: "
        print download_path
        sys.exit(1)

if __name__ == "__main__":
    check_dependencies()
    while 1:
        try:
            print_catalog()
            input = int(get_input())
        except ValueError:
            input = 0
        if input == 1:
            install_image()
        elif input == 2:
            print "For more information visit:\n" \
                  "\thttp://emis.eucalyptus.com"
            exit(0)
        else:
            print "Invalid selection: " + str(input)
