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
# Author: Vic Iglesias <vic.iglesias@eucalyptus.com>
# qemu-img modifications: Brian Thomason <brian.thomason@hp.com>
#
import json
import os
from subprocess import call, Popen, PIPE
import sys
import urllib
import re

catalog_url = "http://emis.eucalyptus.com/catalog-web"
temp_dir_prefix = "emis"

### Answer from:
### http://stackoverflow.com/questions/287871/print-in-terminal-with-colors-using-python
class bcolors:
    HEADER = '\033[37m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

def main_menu():
    return raw_input("Would you like to install an image? (image number or n): ").strip()


def check_output(command):
    process = Popen(command.split(), stdout=PIPE)
    return process.communicate()

def print_error(message):
    print bcolors.FAIL + message + bcolors.ENDC

def print_warning(message):
    print bcolors.WARNING + message + bcolors.ENDC

def print_info(message):
    print bcolors.HEADER + message + bcolors.ENDC

def check_dependencies():
    ### Check that euca2ools 3.1.0 is installed
    try:
        import euca2ools
        (major, minor, patch) = euca2ools.__version__.split('-')[0].split('.')
        if int(major) < 3 or (int(major) >= 3 and int(minor) < 1):
            print_error("Euca2ools version 3.1.0 or newer required.")
            sys.exit(1)
    except ImportError:
        print_error("Euca2ools not found. Instructions can be found here:\n"\
                    "https://www.eucalyptus.com/docs/eucalyptus/4.0/index.html#shared/installing_euca2ools.html")
        sys.exit(1)

    ### Check that xz is installed
    while call(["which", "xz"], stdout=PIPE, stderr=PIPE):
        print_error("Unable to find xz binary.")
        response = raw_input("Would you like to install xz now? (Y/n) ")
        if response == "" or response == 'y' or response == 'Y':
            if call(["yum", "install", "-y", "xz"]):
                print_error("Failed to install xz.")
                sys.exit(1)
        elif response == 'n' or response == 'N':
            print_info("Please install xz and try again.")
            sys.exit(1)
        else:
            print_error("Invalid response.")

    ### Check that wget is installed
    while call(["which", "wget"], stdout=PIPE, stderr=PIPE):
        print_error("Unable to find wget binary.")
        response = raw_input("Would you like to install wget now? (Y/n) ")
        if response == "" or response == 'y' or response == 'Y':
            if call(["yum", "install", "-y", "wget"]):
                print_error("Failed to install wget.")
                sys.exit(1)
        elif response == 'n' or response == 'N':
            print_info("Please install wget and try again.")
            sys.exit(1)
        else:
            print_error("Invalid response.")

    ### Check that qemu-img is installed
    while call(["which", "qemu-img"], stdout=PIPE, stderr=PIPE):
        print_error("Unable to find qemu-img binary.")
        response = raw_input("Would you like to install qemu-img now? (Y/n) ")
        if response == "" or response == 'y' or response == 'Y':
            if call(["yum", "install", "-y", "qemu-img"]):
                print_error("Failed to install qemu-img.")
                sys.exit(1)
        elif response == 'n' or response == 'N':
            print_info("Please install qemu-img and try again.")
            sys.exit(1)
        else:
            print_error("Invalid response.")

    ### Check that creds are sourced
    env = os.environ.copy()
    if not "EC2_URL" in env:
        print_error("Error: Unable to find EC2_URL\nMake sure your eucarc is sourced.")
        sys.exit(1)
    if not "S3_URL" in env:
        print_error("Error: Unable to find S3_URL\nMake sure your eucarc is sourced.")
        sys.exit(1)


def get_catalog():
    return json.loads(urllib.urlopen(catalog_url).read())["images"]


def get_image(number):
    return get_catalog()[number]


def print_catalog():
    catalog = get_catalog()
    format_spec = '{0:3} {1:20} {2:20}'
    print_info(format_spec.format("id","version","description"))
    image_number = 1
    for image in catalog:
        print format_spec.format(str(image_number),image["version"],image["description"])
        image_number += 1
    print


def install_image(number=0, image=None):
    while not image:
        try:
            number = int(raw_input("Enter the image ID you "
                                   "would like to install: "))
            image = get_image(number - 1)
        except (ValueError, KeyError, IndexError):
            print_error("Invalid image selected")
    image_name = image["os"] + "-" + image["created-date"]

    ### Check if image is already registered
    describe_images = "euca-describe-images --filter name={0}".format(image_name)
    (stdout, stderr) = check_output(describe_images)
    if re.search(image_name, stdout):
        print_warning("Image is already registered with this name: " + image_name)
        print_warning(stdout)
        return
    directory_format = '{0}-{1}.XXXXXXXX'.format(temp_dir_prefix, image["os"])

    ### Make temp directory
    (tmpdir, stderr) = check_output('mktemp -d ' + directory_format)

    ### Download image
    download_path = tmpdir.strip() + "/" + image["url"].rsplit("/",1)[-1]
    print_info("Downloading " + image['url'] + " image to: " + download_path)
    if call(["wget", image["url"], "-O", download_path]):
        print_error("Image download failed attempting to download:\n" + image["url"])
        sys.exit(1)

    ### Decompress image, if necessary
    if image["url"].endswith(".xz"):
        print_info("Decompressing image...")
        if call(["xz", "-d", download_path]):
            print_error("Unable to decompress image downloaded to: " + download_path)
            sys.exit(1)
        image_path = download_path.strip(".xz")
        print_info("Decompressed image can be found at: " + image_path)
    else:
        image_path = download_path

    ### Convert image to raw format, if necessary
    if image_path.endswith(".img") or image_path.endswith(".qcow2"):
        print_info("Converting image...")
        image_basename = image_path[0:image_path.rindex(".")]
        if call(["qemu-img", "convert", "-O", "raw", image_path, image_basename + ".raw"]):
            print_error("Unable to convert image")
            sys.exit(1)
        image_path = image_path[0:image_path.rindex(".")] + ".raw"
        print_info("Converted image can be found at: " + image_path)

    ## Install image
    print_info("Installing image to bucket: " + image_name)
    install_cmd = "euca-install-image -r x86_64 -i {0} --virt hvm -b {1} -n {1}".\
        format(image_path, image_name)

    print_info("Running installation command: ")
    print_info(install_cmd)
    if call(install_cmd.split()):
        print_error("Unable to install image that was downloaded to: \n" + download_path)
        sys.exit(1)


def welcome_message():
    title = """
  ______                _             _
 |  ____|              | |           | |
 | |__  _   _  ___ __ _| |_   _ _ __ | |_ _   _ ___
 |  __|| | | |/ __/ _` | | | | | '_ \| __| | | / __|
 | |___| |_| | (_| (_| | | |_| | |_) | |_| |_| \__ \\
 |______\__,_|\___\__,_|_|\__, | .__/ \__|\__,_|___/
                           __/ | |
  __  __            _     |___/|_|       _____
 |  \/  |          | |   (_)            |_   _|
 | \  / | __ _  ___| |__  _ _ __   ___    | |  _ __ ___   __ _  __ _  ___  ___
 | |\/| |/ _` |/ __| '_ \| | '_ \ / _ \   | | | '_ ` _ \ / _` |/ _` |/ _ \/ __|
 | |  | | (_| | (__| | | | | | | |  __/  _| |_| | | | | | (_| | (_| |  __/\__ \\
 |_|  |_|\__,_|\___|_| |_|_|_| |_|\___| |_____|_| |_| |_|\__,_|\__, |\___||___/
                                                                __/ |
                                                               |___/         """
    print_info(title)


def exit_message():
    print
    print_info("For more information visit:\n\thttp://emis.eucalyptus.com")

if __name__ == "__main__":
    check_dependencies()
    welcome_message()
    try:
        while 1:
            try:
                print_catalog()
                input = main_menu()
            except ValueError:
                input = 0
            if input == 'n' or input == 'N':
                exit_message()
                sys.exit(0)
            else:
                try:
                    number = int(input)
                    if number < 1:
                        raise ValueError()
                    image = get_image(number - 1)
                    install_image(image=image)
                except (ValueError, KeyError, IndexError):
                    print_error("Invalid image selected")
    except KeyboardInterrupt:
        exit_message()
