#!/bin/bash

# TODOs:
#   * Pull IP info properly
#   * Check IP addresses for correctness
#   * instructions for importing a larger image than the cirros starter
#   * setup an automated mode that reads the ciab.json file directly
#   * switch to disable "nuke"
#   * add an error parser to pull and report any FATAL chef error, then
#     urlencode and send error message upstream

###############################################################################
# SECTION 1: PRECHECK.
# 
# Any immediately diagnosable condition that might prevent Euca from being
# properly installed should be checked here.
###############################################################################

LOGFILE='/var/log/euca-install-'`date +%m.%d.%Y-%H.%M.%S`'.log'

echo ""
echo ""

# Check to make sure I'm root
echo "[Precheck] Checking root"
ciab_user=`whoami`
if [ "$ciab_user" != 'root' ]; then
    echo "======"
    echo "[FATAL] Not running as root"
    echo ""
    echo "Please run Eucalyptus Faststart as the root user."
    exit 5
fi
echo "[Precheck] OK, running as root"
echo ""

# Check to see that we're running on CentOS or RHEL 6.5.
echo "[Precheck] Checking OS"
grep "6.5" /etc/redhat-release 1>>$LOGFILE
if [ "$?" != "0" ]; then
    echo "======"
    echo "[FATAL] Operating system not supported"
    echo ""
    echo "Please note: Eucalyptus Faststart only runs on RHEL or CentOS 6.5."
    echo "To try Faststart on another platform, consider trying Eucadev:"
    echo "https://github.com/eucalyptus/eucadev"
    echo ""
    echo ""
    curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=OS_NOT_SUPPORTED >> $LOGFILE
    exit 10
fi
echo "[Precheck] OK, OS is supported"
echo ""

# Check to make sure curl is installed.
# If the user is following directions, they should be using
# curl already to fetch the script -- but can't guarantee that.
echo "[Precheck] Checking curl version"
curl --version 1>>$LOGFILE
if [ "$?" != "0" ]; then
    yum -y install curl 1>$LOGFILE
    if [ "$?" != "0" ]; then
        echo "======"
        echo "[FATAL] Could not install curl"
        echo ""
        echo "Failed to install curl. See $LOGFILE for details."
        exit 7
    fi
fi
echo "[Precheck] OK, curl is up to date"
echo ""

# Check to see if kvm is supported by the hardware.
echo "[Precheck] Checking hardware virtualization"
egrep '^flags.*(vmx|svm)' /proc/cpuinfo 1>$LOGFILE
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
    curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=VIRT_NOT_SUPPORTED >> $LOGFILE
    exit 20
fi
echo "[Precheck] OK, processor supports virtualization"
echo ""

# Check to see if chef-solo is installed
echo "[Precheck] Checking if Chef Client is installed"
which chef-solo
if [ "$?" != "0" ]; then
    echo "====="
    echo "[INFO] Chef not found. Installing Chef Client"
    echo ""
    echo ""
    curl -L https://www.opscode.com/chef/install.sh | bash 1>$LOGFILE
    if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Chef install failed!"
        echo ""
        echo "Failed to install Chef. See $LOGFILE for details."
        curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=CHEF_INSTALL_FAILED >> $LOGFILE
        exit 22
    fi
fi
echo "[Precheck] OK, Chef Client is installed"
echo ""

echo "[Precheck] Precheck successful."
echo ""
echo ""

###############################################################################
# SECTION 2: USER INPUT
#
###############################################################################

echo "====="
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

###############################################################################
# SECTION 3: PREP THE INSTALLATION
#
###############################################################################

echo "[Prep] Removing old Chef templates"
# Get rid of old Chef stuff lying about.
rm -rf /var/chef/* 1>$LOGFILE

echo "[Prep] Downloading necessary cookbooks"
# Grab cookbooks from git
yum install -y git 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to install git!"
        echo ""
        echo "Failed to install git. See $LOGFILE for details."
        curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_INSTALL >> $LOGFILE
        exit 24
fi
rm -rf cookbooks
mkdir -p cookbooks
pushd cookbooks
git clone https://github.com/eucalyptus/eucalyptus-cookbook eucalyptus 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch Eucalyptus cookbook!"
        echo ""
        echo "Failed to fetch Eucalyptus cookbook. See $LOGFILE for details."
        curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_EUCA >> $LOGFILE
        exit 25
fi
git clone https://github.com/opscode-cookbooks/yum 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch yum cookbook!"
        echo ""
        echo "Failed to fetch yum cookbook. See $LOGFILE for details."
        curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_YUM >> $LOGFILE
        exit 25
fi
git clone https://github.com/opscode-cookbooks/selinux 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch selinux cookbook!"
        echo ""
        echo "Failed to fetch selinux cookbook. See $LOGFILE for details."
        curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_SELINUX >> $LOGFILE
        exit 25
fi
git clone https://github.com/opscode-cookbooks/ntp 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch ntp cookbook!"
        echo ""
        echo "Failed to fetch ntp cookbook. See $LOGFILE for details."
        curl --silent https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_SELINUX >> $LOGFILE
        exit 25
fi
popd

echo "[Prep] Tarring up cookbooks"
# Tar up the cookbooks for use by chef-solo.
tar czvf cookbooks.tgz cookbooks 1>$LOGFILE

# Copy the CIAB template over to be the active CIAB configuration file.
cp -f cookbooks/eucalyptus/faststart/ciab-template.json ciab.json 

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
echo "  tail -f $LOGFILE"
echo ""
echo "Install in progress..."

chef-solo -r cookbooks.tgz -j ciab.json 1>>$LOGFILE

if [ "$?" != "0" ]; then
    echo "[FATAL] Eucalyptus installation failed"
    echo ""
    echo "Eucalyptus installation failed. Please consult $LOGFILE for details."
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
echo "  source ~/eucarc"
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
