#!/bin/bash

###############################################################################
# TODOs:
#   * Strip out ability to accept defaults?
#   * Add DHCP check and fail with error
#   * Add loop to allow re-entry of network parameters (are these correct?)
#   * Add instructions for importing a larger image than the cirros starter
#   * Insert UUID and tipoftheday
#   * Section borders between Precheck / Prep / Install / Post-install
#   * Option to public pastebin the errors:
#     http://askubuntu.com/questions/186371/how-to-submit-a-file-to-paste-ubuntu-com-without-graphical-interface
#     (and nice messaging about helping the community)
#   * Docs: talk about IP range, not pub/priv IPs, and split the range automatically
#   * add an error parser to pull and report any FATAL chef error, then
#     urlencode and send error message upstream
###############################################################################

###############################################################################
# SECTION 0: FUNCTIONS AND CONSTANTS.
# 
###############################################################################

# Hooray for the coffee cup!
IMGS=(
"
   ( (     \n\
    ) )    \n\
  ........ \n\
  |      |]\n\
  \      / \n\
   ------  \n
" "
   ) )     \n\
    ( (    \n\
  ........ \n\
  |      |]\n\
  \      / \n\
   ------  \n
" )
IMG_REFRESH="0.5"
LINES_PER_IMG=$(( $(echo $IMGS[0] | sed 's/\\n/\n/g' | wc -l) + 1 ))

# Output loop for coffee cup
function tput_loop() 
{ 
    for((x=0; x < $LINES_PER_IMG; x++)); do tput $1; done; 
}

# Let's have some coffee!
function coffee() 
{
    local pid=$1
    IFS='%'
    tput civis
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do for x in "${IMGS[@]}"; do
        echo -ne $x
        tput_loop "cuu1"
        sleep $IMG_REFRESH
    done; done
    tput_loop "cud1"
    tput cvvis
}

# Check IP inputs to make sure they're valid
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Timer check for runtime of the installation
function timer()
{
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local  stime=$1
        etime=$(date '+%s')

        if [[ -z "$stime" ]]; then stime=$etime; fi

        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%d:%02d:%02d' $dh $dm $ds
    fi
}

# Create uuid
uuid=`uuidgen`

###############################################################################
# SECTION 1: PRECHECK.
# 
# Any immediately diagnosable condition that might prevent Euca from being
# properly installed should be checked here.
###############################################################################

# Invoke timer start.
t=$(timer)

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

# If Eucalyptus is already installed, abort and tell the
# user to run nuke.
rpm -q eucalyptus
if [ "$?" == "0" ]; then
    echo "====="
    echo "[FATAL] Eucalyptus already installed!"
    echo ""
    echo "An installation of Eucalyptus has been detected on this system. If you wish to"
    echo "reinstall Eucalyptus, please remove the previous installation first.  If you used"
    echo "Faststart to install previously, you can use the \"nuke\" command:"
    echo ""
    echo "  cd cookbooks/eucalyptus/faststart; ./nuke.sh"
    echo ""
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=EUCA_ALREADY_RUNNING&uuid=$uuid" >> /dev/null
    exit 9
fi

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
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=OS_NOT_SUPPORTED&uuid=$uuid" >> /dev/null
    exit 10
fi
echo "[Precheck] OK, OS is supported"
echo ""

# Check to see if PackageKit is enabled. If it is, abort and advise.
rpm -q PackageKit

if [ "$?" == "0" ]; then
    echo "====="
    echo "[FATAL] PackageKit detected"
    echo ""
    echo "The presence of PackageKit indicates that you have installed a Desktop environment."
    echo "Please run Faststart on a minimal OS without a Desktop environment installed."
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=DESKTOP_NOT_SUPPORTED&uuid=$uuid" >> /dev/null
    exit 12
fi

# Check to see if NetworkManager is enabled. If it is, abort and advise.
rpm -q NetworkManager
if [ "$?" == "0" ]; then
    echo "====="
    echo "[FATAL] NetworkManager detected"
    echo ""
    echo "The presence of NetworkManager indicates that you have installed a Desktop environment."
    echo "Please run Faststart on a minimal OS without a Desktop environment installed."
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=DESKTOP_NOT_SUPPORTEDi&uuid=$uuid" >> /dev/null
    exit 12
fi

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
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=VIRT_NOT_SUPPORTED&uuid=$uuid" >> /dev/null
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
        curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=CHEF_INSTALL_FAILED&uuid=$uuid" >> /dev/null
        exit 22
    fi
fi
echo "[Precheck] OK, Chef Client is installed"
echo ""

echo "[Precheck] Identifying primary network interface"

# Get info about the primary network interface.
# The goal is to walk through the likeliest primary interfaces,
# and when we find an address, assume that we should be using
# the addr, bcast, and mask data.
#
# active_nic identifies the nic that currently holds the active
# primary connection that will be used to identify addr, bcast
# and mask data.
#
# ciab_nic identifies the physical nic -- necessary when the
# active_nic is br0 due to previous bridging attempts.

ciab_nic_guess=""
active_nic=""

if [ "$(ifconfig wlan0 | grep 'inet addr')" ]; then
    echo "====="
    echo "[FATAL] Wireless install not supported!"
    echo ""
    echo "Your primary network interface appears to be a wireless interface."
    echo "Faststart is intended for systems with a fixed ethernet connection and"
    echo "a static IP address. Please reconfigure your system."
    echo ""
    echo "If you want to run a virtual version of Eucalyptus on a laptop,"
    echo "consider trying eucadev instead:"
    echo ""
    echo "  https://github.com/eucalyptus/eucadev"
    echo ""
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=WIRELESS_NOT_SUPPORTED&uuid=$uuid" >> /dev/null
    exit 23
elif [ "$(ifconfig em1 | grep 'inet addr')" ]; then
    echo "Active network interface em1 found"
    ciab_nic_guess="em1"
    active_nic="em1"
elif [ "$(ifconfig eth0 | grep 'inet addr')" ]; then
    echo "Active network interface eth0 found"
    ciab_nic_guess="eth0"
    active_nic="eth0"
elif [ "$(ifconfig br0 | grep 'inet addr')" ]; then
    # This is a corner case: if br0 is the primary interface,
    # it likely means that Eucalyptus has already been 
    # installed and a bridge established. We still need to determine
    # the physical bridhge.
    echo "Virtual network interface br0 found"
    active_nic="br0"
    if [ "$(ifconfig em1)" ]; then
        echo "Physical interface em1 found"
        ciab_nic_guess="em1"
    elif [ "$(ifconfig eth0)" ]; then
        echo "Physical interface eth0 found"
        ciab_nic_guess="eth0"
    else
        echo "====="
        echo "[WARN] No physical ethernet interface found"
        echo ""
        echo "No active ethernet interface was found. Please check your network configuration"
        echo "and make sure that an ethernet interface is set up as your primary network"
        echo "interface, and that it is connected to the internet."
        echo ""
        echo "It's possible that you're using a non-standard network interface (we expect"
        echo "eth0 or em1)."
        echo ""
    fi
else
    echo "====="
    echo "[WARN] No active network interface found"
    echo ""
    echo "No active ethernet interface was found. Please check your network configuration"
    echo "and make sure that an ethernet interface is set up as your primary network"
    echo "interface, and that it's connected to the internet."
    echo ""
    echo "It's possible that you're using a non-standard network interface (we expect"
    echo "eth0 or em1)."
    echo ""
fi
echo "[Precheck] OK, network interfaces checked."
echo ""

echo "[Precheck] OK, running a full update of the OS. This could take a bit; please wait."
echo "To see the update in progress, run the following command in another terminal:"
echo ""
echo "  tail -f $LOGFILE"
echo ""
echo "[Precheck] Package update in progress..."
yum -y update
if [ "$?" != "0" ]; then
    echo "====="
    echo "[FATAL] Chef install failed!"
    echo ""
    echo "Failed to install Chef. See $LOGFILE for details."
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=FULL_YUM_UPDATE_FAILED&uuid=$uuid" >> /dev/null
    exit 24
fi

echo "[Precheck] Precheck successful."
echo ""
echo ""

###############################################################################
# SECTION 2: PREP THE INSTALLATION
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
        curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_INSTALL&uuid=$uuid" >> /dev/null
        exit 25
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
        curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_EUCA&uuid=$uuid" >> /dev/null
        exit 25
fi
git clone https://github.com/opscode-cookbooks/yum 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch yum cookbook!"
        echo ""
        echo "Failed to fetch yum cookbook. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_YUM&uuid=$uuid" >> /dev/null
        exit 25
fi
git clone https://github.com/opscode-cookbooks/selinux 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch selinux cookbook!"
        echo ""
        echo "Failed to fetch selinux cookbook. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_SELINUX&uuid=$uuid" >> /dev/null
        exit 25
fi
git clone https://github.com/opscode-cookbooks/ntp 1>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch ntp cookbook!"
        echo ""
        echo "Failed to fetch ntp cookbook. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=FAILED_GIT_CLONE_NTP&uuid=$uuid" >> /dev/null
        exit 25
fi
popd

echo "[Prep] Tarring up cookbooks"
# Tar up the cookbooks for use by chef-solo.
tar czvf cookbooks.tgz cookbooks 1>$LOGFILE

# Copy the CIAB template over to be the active CIAB configuration file.
cp -f cookbooks/eucalyptus/faststart/ciab-template.json ciab.json 

###############################################################################
# SECTION 3: USER INPUT
#
###############################################################################

echo "====="
echo ""
echo "Welcome to the Faststart installer!"

echo "We're about to turn this system into a single-system Eucalyptus cloud."
echo "To do that, we need to get a few answers from you."

# Attempt to prepopulate values
ciab_ipaddr_guess=`ifconfig $active_nic | grep "inet addr" | awk '{print $2}' | cut -d':' -f2`
ciab_gateway_guess=`/sbin/ip route | awk '/default/ { print $3 }'`
ciab_netmask_guess=`ipcalc -m $ciab_ipaddr_guess | cut -d'=' -f2`
ciab_subnet_guess=`ipcalc -n $ciab_ipaddr_guess $ciab_netmask_guess | cut -d'=' -f2`

echo ""
echo "What's the physical NIC that will be used for bridging? ($ciab_nic_guess)"
read ciab_nic
[[ -z "$ciab_nic" ]] && ciab_nic=$ciab_nic_guess
echo "NIC="$ciab_nic
echo ""

echo "What's the IP address of this host? ($ciab_ipaddr_guess)"
until valid_ip $ciab_ipaddr; do
    read ciab_ipaddr
    [[ -z "$ciab_ipaddr" ]] && ciab_ipaddr=$ciab_ipaddr_guess
    valid_ip $ciab_ipaddr || echo "Please provide a valid IP."
done
echo "IPADDR="$ciab_ipaddr
echo ""

echo "What's the gateway for this host? ($ciab_gateway_guess)"
until valid_ip $ciab_gateway; do
    read ciab_gateway
    [[ -z "$ciab_gateway" ]] && ciab_gateway=$ciab_gateway_guess
    valid_ip $ciab_gateway || echo "Please provide a valid IP."
done
echo "GATEWAY="$ciab_gateway
echo ""

echo "What's the netmask for this host? ($ciab_netmask_guess)"
until valid_ip $ciab_netmask; do
    read ciab_netmask
    [[ -z "$ciab_netmask" ]] && ciab_netmask=$ciab_netmask_guess
    valid_ip $ciab_netmask || echo "Please provide a valid IP."
done
echo "NETMASK="$ciab_netmask
echo ""

echo "What's the subnet for this host? ($ciab_subnet_guess)"
until valid_ip $ciab_subnet; do
    read ciab_subnet
    [[ -z "$ciab_subnet" ]] && ciab_subnet=$ciab_subnet_guess
    valid_ip $ciab_subnet || echo "Please provide a valid IP."
done
echo "SUBNET="$ciab_subnet
echo ""

echo "What's the first address of your public IP range?"
until valid_ip $ciab_publicips1; do
    read ciab_publicips1
    valid_ip $ciab_publicips1 || echo "Please provide a valid IP."
done
echo ""

echo "What's the last address of your public IP range?"
until valid_ip $ciab_publicips2; do
    read ciab_publicips2
    valid_ip $ciab_publicips2 || echo "Please provide a valid IP."
done
echo ""

echo "What's the first address of your private IP range?"
until valid_ip $ciab_privateips1; do
    read ciab_privateips1
    valid_ip $ciab_privateips1|| echo "Please provide a valid IP."
done
echo ""

echo "What's the last address of your private IP range?"
until valid_ip $ciab_privateips2; do
    read ciab_privateips2
    valid_ip $ciab_privateips2|| echo "Please provide a valid IP."
done
echo ""

# Perform variable interpolation in the CIAB template.
sed -i "s/IPADDR/$ciab_ipaddr/g" ciab.json
sed -i "s/NETMASK/$ciab_netmask/g" ciab.json
sed -i "s/GATEWAY/$ciab_gateway/g" ciab.json
sed -i "s/SUBNET/$ciab_subnet/g" ciab.json
sed -i "s/PUBLICIPS1/$ciab_publicips1/g" ciab.json
sed -i "s/PUBLICIPS2/$ciab_publicips2/g" ciab.json
sed -i "s/PRIVATEIPS1/$ciab_privateips1/g" ciab.json
sed -i "s/PRIVATEIPS2/$ciab_privateips2/g" ciab.json
sed -i "s/NIC/$ciab_nic/g" ciab.json

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
echo "If you want to watch the progress of this installation, you can check the"
echo "log file by running the following command in another terminal:"
echo ""
echo "  tail -f $LOGFILE"
echo ""
echo "Note: this install might take a while. Go have a cup of coffee!"
echo ""

# To make the spinner work, we need to launch in a subshell.  Since we 
# can't get variables from the subshell scope, we'll write success or
# failure to a file, and then succeed or fail based on whether the file
# exists or not.

rm -f faststart-successful.log
(chef-solo -r cookbooks.tgz -j ciab.json 1>>$LOGFILE && echo "success" > faststart-successful.log) &
coffee $!

if [[ ! -f faststart-successful.log ]]; then
    echo "[FATAL] Eucalyptus installation failed"
    echo ""
    echo "Eucalyptus installation failed. Please consult $LOGFILE for details."
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=CHEF_INSTALL_FAILED&uuid=$uuid" >> /dev/null
    exit 99
fi

echo ""
echo ""
echo "[SUCCESS] Eucalyptus installation complete!"
total_time=$(timer $t)
printf 'Time to install: %s\n' $total_time
curl --silent "https://www.eucalyptus.com/faststart_errors.html?fserror=$total_time&uuid=$uuid" >> /dev/null

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
echo "Thanks for installing Eucalyptus!"
echo ""
exit 0

