#!/bin/bash

# Assumes:
#   1. valid cookbooks in ./cookbooks directory;
#   2. valid nuke.json runlist;
#   3. valid ciab.json runlist.

###############################################################################
# SECTION 1: PRECHECK.
# 
# Any immediately diagnosable condition that might prevent Euca from being
# properly installed should be checked here.
###############################################################################

echo ""
echo ""

# Check to make sure I'm root
echo "[Precheck] Checking root"
ciab_user=`whoami`
if [ "$ciab_user" != 'root' ]; then
    echo "[FATAL] Not running as root"
    echo ""
    echo "Please run Eucalyptus Faststart as the root user."
    exit 5
fi
echo "[Precheck] OK, running as root"
echo ""
echo ""

# Check to see that we're running on CentOS or RHEL 6.5.
echo "[Precheck] Checking OS"
grep "6.5" /etc/redhat-release 
if [ "$?" != "0" ]; then
    echo "======"
    echo "[FATAL] Operating system not supported"
    echo ""
    echo "Please note: Eucalyptus Faststart only runs on RHEL or CentOS 6.5."
    echo "To try Faststart on another platform, consider trying Eucadev:"
    echo "https://github.com/eucalyptus/eucadev"
    echo ""
    echo ""
    wget -q https://www.eucalyptus.com/docs/tipoftheday.html?fserror=OS_NOT_SUPPORTED -O /dev/null
    exit 10
fi
echo "[Precheck] OK, OS is supported"
echo ""
echo ""

# Check to see if kvm is supported by the hardware.
echo "[Precheck] Checking hardware virtualization"
egrep '^flags.*(vmx|svm)' /proc/cpuinfo
if [ "$?" != "0" ]; then
    echo "====="
    echo "[FATAL] Processor doesn't support virtualization"
    echo ""
    echo "Your processor doesn't appear to support virtualization."
    echo "Eucalyptus requires virtualization to be enabled on your system."
    echo "Please check your BIOS settings, or install Eucalyptus on a"
    echo "system that supports virtualization."
    echo ""
    echo ""
    wget -q https://www.eucalyptus.com/docs/tipoftheday.html?fserror=VIRT_NOT_SUPPORTED -O /dev/null
    exit 20
fi
echo "[Precheck] OK, processor supports virtualization"
echo ""
echo ""

echo "[Precheck] Precheck successful."
echo ""
echo ""

###############################################################################
# SECTION 2: USER INPUT
#
# For now, we're going to harcode the variables to make sure that the 
# template replacement works properly.
#
# TODO: setup an interactive mode that asks all the necessary questions
# TODO: setup an automated mode that reads the ciab.json file directly
###############################################################################

# Set the IP addresses.
ciab_ipaddr="192.168.1.160"
ciab_netmask="255.255.255.0"
ciab_gateway="192.168.1.1"
ciab_subnet="192.168.1.0"
ciab_publicips1="192.168.1.161"
ciab_publicips2="192.168.1.170"
ciab_privateips1="192.168.1.171"
ciab_privateips2="192.168.1.180"

# Copy the CIAB template over to be the active CIAB configuration file.
cp -f ciab-template.json ciab.json 

# Perform variable interpolation in the CIAB template.
sed -i "s/IPADDR/$ciab_ipaddr/g" ciab.json
sed -i "s/NETMASK/$ciab_netmask/g" ciab.json
sed -i "s/GATEWAY/$ciab_gateway/g" ciab.json
sed -i "s/SUBNET/$ciab_subnet/g" ciab.json
sed -i "s/PUBLICIPS1/$ciab_publicips1/g" ciab.json
sed -i "s/PUBLICIPS2/$ciab_publicips2/g" ciab.json
sed -i "s/PRIVATEIPS1/$ciab_privateips1/g" ciab.json
sed -i "s/PRIVATEIPS2/$ciab_privateips2/g" ciab.json

###############################################################################
# SECTION 3: PREP THE INSTALLATION
#
# TODO: Add a confirm for interactive mode: "this will blow away any
# current Eucalyptus installation on this machine, are you sure?"
###############################################################################

echo "[Prep] Removing old Chef templates"
# Get rid of old Chef stuff lying about.
rm -rf /var/chef/*

echo "[Prep] Tarring up cookbooks"
# Tar up the cookbooks for use by chef-solo.
tar czvf cookbooks.tgz cookbooks

echo "[Prep] Nuking any previous Euca installation"
# Run the nuke recipe, which gets rid of all traces of Euca.
chef-solo -r cookbooks.tgz -j nuke.json 1>/tmp/ciab.nuke.out

###############################################################################
# SECTION 4: INSTALL EUCALYPTUS
#
# TODO: Add successful run time
# TODO: Add an error parser to pull and report any FATAL chef error
# TODO: urlencode and send error message upstream
###############################################################################

# Install Euca and start it up in the cloud-in-a-box configuration.
echo ""
echo ""
echo "[Installing Eucalyptus]"
echo ""
echo "Please note: this installation will take a while. Go grab a cup of coffee."
echo "If you want to watch the progress of this installation, you can check the"
echo "log file by running the following command in another terminal:"
echo ""
echo "tail -f /tmp/ciab.install.out"

chef-solo -r cookbooks.tgz -j ciab.json 1>/tmp/ciab.install.out

if [ "$?" != "0" ]; then
    echo "[FATAL] Eucalyptus installation failed"
    echo ""
    echo "Eucalyptus installation failed. Please consult the file /tmp/ciab.install.out for details."
    exit 99
fi

echo ""
echo ""
echo "[SUCCESS] Eucalyptus installation complete!"
exit 0
