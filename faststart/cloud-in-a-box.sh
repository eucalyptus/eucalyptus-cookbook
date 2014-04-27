#!/bin/bash

# Assumes:
#   * valid nuke.json runlist;
#   * valid ciab.json runlist.

# TODOs:
#   * come up with a timestamp for the master log file
#   * send all output to the master log file
#   * import a larger image than the cirros starter
#   * pull the raw ciab-template file directly from Github
#   * setup an interactive mode that asks all the necessary questions
#   * setup an automated mode that reads the ciab.json file directly
#   * switch to disable "nuke"
#   * add successful run time
#   * add an error parser to pull and report any FATAL chef error, then
#     urlencode and send error message upstream

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
    wget -q https://www.eucalyptus.com/faststart_errors.html?fserror=OS_NOT_SUPPORTED -O /dev/null
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
    wget -q https://www.eucalyptus.com/faststart_errors.html?fserror=VIRT_NOT_SUPPORTED -O /dev/null
    exit 20
fi
echo "[Precheck] OK, processor supports virtualization"
echo ""
echo ""

# Check to see if chef-solo is installed
echo "[Precheck] Checking if Chef Client is installed"
which chef-solo
if [ "$?" != "0" ]; then
    echo "====="
    echo "[INFO] Installing Chef Client"
    echo ""
    echo ""
    curl -L https://www.opscode.com/chef/install.sh | bash
fi
echo "[Precheck] OK, Chef Client is installed"
echo ""
echo ""

echo "[Precheck] Precheck successful."
echo ""
echo ""

###############################################################################
# SECTION 2: USER INPUT
#
###############################################################################

echo ""
echo ""
echo "Welcome to the Faststart installer!"

echo "We're about to turn this system into a single-system Eucalyptus cloud."
echo "To do that, we need to get a few answers from you."
echo "(NOTE: we're not validating any of these inputs yet.)"

echo ""
echo "What's the IP address of this host? (example: 192.168.1.100) (Yes, I know: we should detect this.)"
read ciab_ipaddr
echo "What's the gateway for this host? (example: 192.168.1.1) (Yes, we should detect this too.)"
read ciab_gateway
echo "What's the subnet for this host? (example: 192.168.1.0) (Yes, we should also detect this.)"
read ciab_subnet
echo "What's the netmask for this host? (example: 255.255.255.0) (Yes, we should be able to compute this.)"
read ciab_netmask
echo "What's the first address of your public IP range?"
read ciab_publicips1
echo "What's the last address of your public IP range?"
read ciab_publicips2
echo "What's the first address of your private IP range?"
read ciab_privateips1
echo "What's the last address of your private IP range?"
read ciab_privateips2

# Set the IP addresses.
#ciab_ipaddr="192.168.1.160"
#ciab_netmask="255.255.255.0"
#ciab_gateway="192.168.1.1"
#ciab_subnet="192.168.1.0"
#ciab_publicips1="192.168.1.161"
#ciab_publicips2="192.168.1.170"
#ciab_privateips1="192.168.1.171"
#ciab_privateips2="192.168.1.180"

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
###############################################################################

echo "[Prep] Removing old Chef templates"
# Get rid of old Chef stuff lying about.
rm -rf /var/chef/*

echo "[Prep] Downloading necessary cookbooks"
# Grab cookbooks from git
yum install -y git
rm -rf cookbooks
mkdir -p cookbooks
pushd cookbooks
git clone https://github.com/eucalyptus/eucalyptus-cookbook eucalyptus
git clone https://github.com/opscode-cookbooks/yum
git clone https://github.com/opscode-cookbooks/selinux
git clone https://github.com/opscode-cookbooks/ntp
popd

echo "[Prep] Tarring up cookbooks"
# Tar up the cookbooks for use by chef-solo.
tar czvf cookbooks.tgz cookbooks

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
echo ""
echo "Install in progress..."

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
echo ""
echo "We've launched a simple instance for you. To start exploring your new Eucalyptus cloud,"
echo "you should:"
echo ""
echo "Source your new credentials:"
echo "  source ~/.eucarc"
echo ""
echo "Get a list of your running cloud instances:"
echo "  euca-describe-instances"
echo ""
echo "Get a list of your available cloud images:"
echo ""
echo "  euca-describe-images"
echo ""
echo "For more information, consult the Eucalyptus User Guide at:"
echo "  https://www.eucalyptus.com/docs/eucalyptus/3.4/index.html#shared/user_section.html"
echo ""
echo "Thanks for installating Eucalyptus!"
echo ""
exit 0
