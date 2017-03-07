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
#         Imran Hossain Shaon <imran.hossain@hpe.com>
# qemu-img modifications: Brian Thomason <brian.thomason@hp.com>
#

#
# TODO: add check for env variables for user credentials
#
import argparse
import json
import os
import re
import sys
import ConfigParser
import urllib

import time

from subprocess import Popen, PIPE, call


class EmiManager:
    def __init__(self, user, region,
                 catalog_url="http://shaon.me/catalog-web"):
        self.user = user
        self.region = region
        self.catalog_url = catalog_url
        self.temp_dir_prefix = "emis"

    def check_dependencies(self):
        deps_list = ["wget", "xz", "bzip2"]

        print
        sys.stdout.write("\t\t%s\r" % "checking euca2ools...")
        try:
            cmd = call("type " + "euca-describe-instances", shell=True,
                       stdout=PIPE, stderr=PIPE)
            if cmd:
                raise RuntimeError
        except (ImportError, RuntimeError):
            sys.stdout.flush()
            time.sleep(0.5)
            print_error("\r\t\tchecking euca2ools... failed")
            time.sleep(0.5)
            print_error("Euca2ools not found.\n")
            print_info("Install instructions can be found here:\n"
                       "https://www.eucalyptus.com/docs/eucalyptus/4.2/"
                       "index.html#shared/installing_euca2ools.html")
            sys.exit("Bye")
        sys.stdout.flush()
        time.sleep(0.5)
        print_success("\t\tchecking euca2ools... ok")
        time.sleep(0.5)

        for package in deps_list:
            print
            sys.stdout.write("\t\tchecking %s\r" % (package + "..."))
            if call(["which", package], stdout=PIPE, stderr=PIPE):
                sys.stdout.flush()
                time.sleep(0.5)
                print_error("\t\tchecking %s" % (package + "... failed"))
                time.sleep(0.5)
            else:
                sys.stdout.flush()
                time.sleep(0.5)
                print_success("\t\tchecking %s" % (package + "... ok"))
                time.sleep(0.5)

        for pkg in deps_list:
            self.install_package(pkg)

    def install_package(self, package_name, nogpg=False):
        while call(["which", package_name], stdout=PIPE, stderr=PIPE):
            if call(["yum", "install", "-y", package_name]):
                print_error("Failed to install " + package_name + ".")
                sys.exit("Bye")

    def install_qemu_img(self):
        if call(["yum", "install", "-y", "--nogpgcheck", "qemu-img"]):
            print_error("Failed to install qemu-img.")
            sys.exit("Bye")

    def get_catalog(self):
        return json.loads(urllib.urlopen(self.catalog_url).read())["images"]

    def print_catalog(self):
        print "Select an image Id from the following table: "
        print
        catalog = self.get_catalog()
        format_spec = '{0:3} {1:20} {2:20} {3:20} {4:10}'
        print_bold(
            format_spec.format("id", "version", "image-format", "created-date",
                               "description"))
        image_number = 1
        for image in catalog:
            if not image["image-format"]:
                image["image-format"] = "None"
            print format_spec.format(str(image_number), image["version"],
                                     image["image-format"],
                                     image["created-date"],
                                     image["description"])
            image_number += 1
        print

    def get_image(self, retry=2):
        self.print_catalog()
        while retry > 0:
            try:
                number = int(raw_input(
                    "Enter the image ID you would like to install: "))
                if (number - 1 < 0) or (number - 1 > len(self.get_catalog())):
                    print_error(
                        "Invalid image Id. "
                        "Please select an Id from the table.")
                    raise ValueError
                image = self.get_catalog()[number - 1]
                return image
            except (ValueError, KeyError, IndexError):
                retry -= 1
        sys.exit("Bye")

    def install_image(self, image):
        if image["image-format"] == "qcow2":
            print_info(
                "This image is available in 'qcow2' "
                "format and requires qemu-img "
                "package for 'raw' conversion.\n")
            # Check that qemu-img is installed
            sys.stdout.write("\t\t%s\r" % "checking qemu-img...")
            if call(["which", "qemu-img"], stdout=PIPE, stderr=PIPE):
                sys.stdout.flush()
                time.sleep(1)
                print_error("\t\tchecking %s" % "qemu-img... failed")
                time.sleep(1)
                install_qemu = "Install 'qemu-img' package? (Y/n): ".strip()
                if check_response(install_qemu):
                    self.install_qemu_img()
                else:
                    sys.exit("Bye")
            else:
                sys.stdout.flush()
                time.sleep(1)
                print_success("\t\tchecking %s" % "qemu-img... ok")
                time.sleep(1)

        image_name = image["os"] + "-" + image["created-date"]

        describe_images = "euca-describe-images --filter name={0} " \
                          "--region {1}@{2}".format(image_name,
                                                    self.user, self.region)
        (stdout, stderr) = self.check_output(describe_images)
        if re.search(image_name, stdout):
            print_warning(
                "Warning: An image with name '" + image_name +
                "' is already install.")
            print_warning(stdout)
            install_image = "Continue? (Y/n) : ".strip()
            if check_response(install_image):
                image_name = image['os'] + "-" + str(time.time())
            else:
                sys.exit("Bye")
        directory_format = '{0}-{1}.XXXXXXXX'.format(self.temp_dir_prefix,
                                                     image["os"])

        # Make temp directory
        (tmpdir, stderr) = self.check_output('mktemp -d ' + directory_format)

        # Download image
        download_path = tmpdir.strip() + "/" + image["url"].rsplit("/", 1)[-1]
        print_info(
            "Downloading " + image['url'] + " image to: " + download_path)
        if call(["wget", image["url"], "-O", download_path]):
            print_error(
                "Image download failed attempting to download:\n" + image[
                    "url"])
            sys.exit("Bye")

        # Decompress image, if necessary
        if image["url"].endswith(".xz"):
            print_info("Decompressing image...")
            if call(["xz", "-d", download_path]):
                print_error(
                    "Unable to decompress image downloaded to: " +
                    download_path)
                sys.exit("Bye")
            image_path = download_path.strip(".xz")
            print_info("Decompressed image can be found at: " + image_path)
        elif image["url"].endswith(".bz2"):
            print_info("Decompressing image...")
            if call(["bzip2", "-d", download_path]):
                print_error(
                    "Unable to decompress image downloaded to: " +
                    download_path)
                sys.exit("Bye")
            image_path = download_path.strip(".bz2")
            print_info("Decompressed image can be found at: " + image_path)
        else:
            image_path = download_path

        # Convert image to raw format, if necessary
        if image["image-format"] == "qcow2":
            print_info("Converting image...")
            image_basename = image_path[0:image_path.rindex(".")]
            if call(["qemu-img", "convert", "-O", "raw", image_path,
                     image_basename + ".raw"]):
                print_error("Unable to convert image")
                sys.exit("Bye")
            image_path = image_path[0:image_path.rindex(".")] + ".raw"
            print_info("Converted image can be found at: " + image_path)

        print_info("Installing image to bucket: " + image_name + "\n")
        install_cmd = "euca-install-image -r x86_64 -i {0} --virt hvm " \
                      "-b {1} -n {1} --region {2}@{3}". \
            format(image_path, image_name, self.user, self.region)

        print_info("Running installation command: ")
        print_info(install_cmd)
        if call(install_cmd.split()):
            print_error("Unable to install image that was downloaded to: \n" +
                        download_path)
            sys.exit("Bye")

    def check_output(self, command):
        process = Popen(command.split(), stdout=PIPE)
        return process.communicate()


class EucaCredentials(object):
    def __init__(self, home_dir='/root', conf_dir='.euca', ext='.ini'):
        self.ext = ext
        self.home_dir = home_dir
        self.conf_dir = conf_dir
        config = self.get_config()
        sections = config.sections()
        self.region = self.select_region(sections)
        self.user = self.select_user(sections)

    def select_user(self, sections):
        users = self.get_sections('user', sections)
        print_success("Found " + str(len(users)) + " available user/s in " +
                      os.path.join(self.home_dir, self.conf_dir))
        self.print_info(users)
        try:
            number = int(raw_input("\nSelect User ID: "))
            user = (users[number - 1]).split(' ')[1]
            return user
        except (ValueError, KeyError, IndexError):
            print "Invalid user selected\n"
            sys.exit("Bye")

    def select_region(self, sections):
        regions = self.get_sections('region', sections)
        print_success("Found " + str(len(regions)) +
                      " available region/s in " +
                      os.path.join(self.home_dir, self.conf_dir))
        self.print_info(regions)
        try:
            number = int(raw_input("\nSelect Region ID: "))
            region = (regions[number - 1]).split(' ')[1]
            return region
        except (ValueError, KeyError, IndexError):
            print_error("Invalid region selected\n")
            sys.exit("Bye")

    def get_config(self):
        print_info("Reading user credentials...\n")
        try:
            directory = os.path.join(self.home_dir, self.conf_dir)
            files = os.listdir(directory)
            abs_files = []
            for f in files:
                abs_files.append(os.path.join(directory, f))
            res = filter(lambda x: x.endswith(self.ext), abs_files)
            config = ConfigParser.ConfigParser()
            config.read(res)
            return config
        except Exception, e:
            print e
            print_error("Error: Cannot find directory or .ini file " +
                        os.path.join(self.home_dir, self.conf_dir))
            print_error("Create admin config file: "
                        "eval `clcadmin-assume-system-credentials`; "
                        "euare-useraddkey admin -wd <dns domain name> > "
                        ".euca/admin.ini\n")
            exit(1)

    def get_sections(self, name, section_list):
        return filter(lambda x: x.startswith(name), section_list)

    def print_info(self, key_val_list):
        index = 1
        format_spec = '{0:3} {1:10} {2:30}'
        print
        print_bold(format_spec.format("id", "type", "value"))
        for kvl in key_val_list:
            kv = kvl.split(' ')
            try:
                print format_spec.format(str(index), kv[0], kv[1])
            except IndexError, e:
                print_error("Incorrect syntaxt for: " + kv)
            index += 1


class bcolors:
    """
    Courtesy: http://stackoverflow.com/questions/287871
    """
    HEADER = '\033[37m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    BOLD = '\033[1m'
    ENDC = '\033[0m'


def check_response(query_string):
    response = raw_input(query_string)
    if response.lower() == 'y' or response == '':
        return True
    else:
        return False


def print_error(message):
    print bcolors.FAIL + message + bcolors.ENDC


def print_warning(message):
    print bcolors.WARNING + message + bcolors.ENDC


def print_success(message):
    print bcolors.OKGREEN + message + bcolors.ENDC


def print_debug(message):
    print bcolors.HEADER + "[debug] " + message + bcolors.ENDC


def print_info(message):
    print bcolors.HEADER + message + bcolors.ENDC


def print_bold(message):
    print bcolors.BOLD + message + bcolors.ENDC


def print_title():
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

    print_success(title)


def exit_message():
    print
    print "For more information visit:\n\thttp://emis.eucalyptus.com"


def main():
    parser = argparse.ArgumentParser(description='Process Arguments.')
    parser.add_argument('-c', '--catalog',
                        default="https://raw.githubusercontent.com/shaon/scripts/master/catalog-web",
                        help='Image catalog json file')
    args = parser.parse_args()

    print_title()
    euca_creds = EucaCredentials()
    emi_manager = EmiManager(euca_creds.user, euca_creds.region,
                             catalog_url=args.catalog)
    emi_manager.check_dependencies()
    image = emi_manager.get_image()
    emi_manager.install_image(image)

    exit_message()


if __name__ == "__main__":
    main()
