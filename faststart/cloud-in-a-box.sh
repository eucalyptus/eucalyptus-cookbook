#!/bin/bash

# Taken from
# http://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
OPTIND=1  # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
cookbooks_url="http://euca-chef.s3.amazonaws.com/eucalyptus-cookbooks-4.2.0.tgz"
nc_install_only=0

function usage
{
    echo "usage: cloud-in-a-box.sh [[[-u path-to-cookbooks-tgz ] [--nc]] | [-h]]"
}

while [ "$1" != "" ]; do
    case $1 in
        -u | --cookbooks-url )           shift
                                         cookbooks_url=$1
                                ;;
        --nc )                  nc_install_only=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

###############################################################################
# TODOs:
#   * Put *all* output for *all* commands into log file
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

# Offer free support for the more difficult errors
function offer_support()
{
    errorCondition=$1
    echo "Upload log file to improve quality? [Y/n]"
    read continue_upload
    if [ "$continue_upload" = "Y" ] || [ "$continue_upload" == "y" ]
    then
        curl -Ls https://raw.githubusercontent.com/eucalyptus/eucalyptus-cookbook/master/faststart/faststart-logger.priv > /tmp/faststart-logger.priv
        chmod 0600 /tmp/faststart-logger.priv
        mkdir /tmp/$uuid
        echo "Let us gather some environment data."
        df -B M >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        ps aux >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        free >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        uptime >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        iptables -L >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        iptables -L -t nat >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        arp -a >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        ip addr show >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        ip link show >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        brctl show >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        route >> /tmp/$uuid/env.log
        printf "\n\n====================================\n\n" >> /tmp/$uuid/env.log
        netstat -lnp >> /tmp/$uuid/env.log

        cp $LOGFILE /tmp/$uuid/ &> /dev/null
        cp -r /var/log/eucalyptus/* /tmp/$uuid/ &> /dev/null
        tar -czvf /tmp/$uuid.tar.gz /tmp/$uuid &> /dev/null
        echo "put /tmp/$uuid.tar.gz" | sftp -b - -o StrictHostKeyChecking=no -o IdentityFile=/tmp/faststart-logger.priv faststart-logger@dropbox.eucalyptus.com:./uploads/
    fi
    echo ""
    echo "Free support is available for this error. Visit this link to speak"
    echo "with the Eucalyptus technical community:"
    echo "     http://bit.ly/euca-users"
    echo "Or find us on IRC at irc.freenode.net, on the #eucalyptus channel."
    echo "     http://bit.ly/euca-irc"
} 

# Notify support team that a user wants help
function submit_support_request()
{
    emailAddress=$1
    errorCondition=$2
    installLogFile=$3

    # Build the URL used to call Marketo for this new account
    dataString="mktForm_116=mktForm_116"
    dataString="$dataString&""Email=$emailAddress"
    dataString="$dataString&""FastStart_Install_Error_Msg__c=$errorCondition"
    dataString="$dataString&""fastStartInstallLog=$installLogFile"
    dataString="$dataString&""mktFrmSubmit=Submit"
    dataString="$dataString&""lpId=4976"
    dataString="$dataString&""subId=198"
    dataString="$dataString&""munchkinId=729-HPK-685"
    dataString="$dataString&""lpurl=http%3A%2F%2Fgo.eucalyptus.com/FastStart-Install-Support?cr={creative}&kw={keyword}"
    dataString="$dataString&""formid=116"
    dataString="$dataString&""_mkt_dis=return"
  
    curl -s --data "$dataString"  http://go.eucalyptus.com/index.php/leadCapture/save >> /tmp/fsout.log
}

# Create uuid
uuid=`uuidgen -t`

###############################################################################
# SECTION 1: PRECHECK.
# 
# Any immediately diagnosable condition that might prevent Euca from being
# properly installed should be checked here.
###############################################################################

# WARNING: if you're running on a laptop, turn sleep off in BIOS!
# Sleep can affect VMs badly.

echo "NOTE: if you're running on a laptop, you might want to make sure that"
echo "you have turned off sleep/ACPI in your BIOS.  If the laptop goes to sleep,"
echo "virtual machines could terminate."
echo ""

echo "Continue? [Y/n]"
read continue_laptop
if [ "$continue_laptop" = "n" ] || [ "$continue_laptop" = "N" ]
then 
    echo "Stopped by user request."
    exit 1
fi

# Invoke timer start.
t=$(timer)

LOGFILE='/var/log/euca-install-'`date +%m.%d.%Y-%H.%M.%S`'.log'

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
    yum -y install curl 1>>$LOGFILE
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

if [ "$nc_install_only" == "1" ];
then
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=NC_INSTALL_BEGIN&id=$uuid" >> /tmp/fsout.log
else
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=EUCA_INSTALL_BEGIN&id=$uuid" >> /tmp/fsout.log
fi


# Check disk space.
DiskSpace=`df -Pk /var | tail -1 | awk '{ print $4}'`

if [ "$DiskSpace" -lt "100000000" ]; then
    echo "WARNING: we recommend at least 100G of disk space available"
    echo "in /var for a Eucalyptus Faststart installation.  Running with"
    echo "less disk space may result in issues with image and volume"
    echo "management, and may dramatically reduce the number of instances"
    echo "your cloud can run simultaneously."
    echo ""
    echo "Your free space is: `df -Ph /var | tail -1 | awk '{ print $4}'`"
    echo ""
    echo "Continue? [y/N]"
    read continue_disk
    if [ "$continue_disk" = "n" ] || [ "$continue_disk" = "N" ] || [ -z "$continue_disk" ]
    then 
        echo "Stopped by user request."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=NOT_ENOUGH_DISK_SPACE&id=$uuid" >> /tmp/fsout.log
        exit 1
    fi
fi

# If Eucalyptus is already installed, abort and tell the
# user to run nuke.
rpm -q eucalyptus
if [ "$?" == "0" ]; then
    echo "====="
    echo "[FATAL] Eucalyptus already installed!"
    echo ""
    echo "An installation of Eucalyptus has been detected on this system. If you wish to"
    echo "reinstall Eucalyptus, please remove the previous installation first.  If you used"
    echo "Faststart to install previously, you can run the \"nuke\" recipe:"
    echo ""
    echo "  chef-client -z -o eucalyptus::nuke"
    echo ""
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=EUCA_ALREADY_RUNNING&id=$uuid" >> /tmp/fsout.log
    exit 9
fi

# Check to see that we're running on CentOS or RHEL and the right version.
echo "[Precheck] Checking OS"
cat /etc/redhat-release | egrep 'release.*7.[2]' 1>>$LOGFILE
if [ "$?" != "0" ]; then
    echo "======"
    echo "[FATAL] Operating system not supported"
    echo ""
    echo "Please note: Eucalyptus Faststart only runs on RHEL or CentOS 7.2"
    echo "To try Faststart on another platform, consider trying Eucadev:"
    echo "https://github.com/eucalyptus/eucalyptus-cookbook/blob/master/eucadev.md"
    echo ""
    echo ""
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=OS_NOT_SUPPORTED&id=$uuid" >> /tmp/fsout.log
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
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=DESKTOP_NOT_SUPPORTED&id=$uuid" >> /tmp/fsout.log
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
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=DESKTOP_NOT_SUPPORTED&id=$uuid" >> /tmp/fsout.log
    exit 12
fi

# Check to see if kvm is supported by the hardware.
echo "[Precheck] Checking hardware virtualization"
egrep '^flags.*(vmx|svm)' /proc/cpuinfo 1>>$LOGFILE
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
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=VIRT_NOT_SUPPORTED&id=$uuid" >> /tmp/fsout.log
    exit 20
fi
echo "[Precheck] OK, processor supports virtualization"
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
ciab_bridge_primary="0"

primary_from_route=$(ip route | grep default | awk '{print $5}')
if [ "$primary_from_route" != "" ]; then
  echo ""
  echo "Found network device: $primary_from_route"
  echo ""
  if [ "$primary_from_route" == "wlan0" ]; then
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
    echo "  https://github.com/eucalyptus/eucalyptus-cookbook/blob/master/eucadev.md"
    echo ""
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=WIRELESS_NOT_SUPPORTED&id=$uuid" >> /tmp/fsout.log
    exit 23
  elif [ "$primary_from_route" == "br0" ]; then
    # This is a corner case: if br0 is the primary interface,
    # it likely means that Eucalyptus has already been 
    # installed and a bridge established. We still need to determine
    # the physical bridge.
    echo "Virtual network interface br0 found"
    active_nic="br0"
    if [ "$(ip link show em1 2>/dev/null)" ]; then
        echo "Physical interface em1 found"
        ciab_nic_guess="em1"
        ciab_bridge_primary="1"
    elif [ "$(ip link show eth0 2>/dev/null)" ]; then
        echo "Physical interface eth0 found"
        ciab_nic_guess="eth0"
        ciab_bridge_primary="1"
    elif [ "$(ip link show eno1 2>/dev/null)" ]; then
        echo "Physical interface en01 found"
        ciab_nic_guess="en01"
        ciab_bridge_primary="1"
    else
        echo "====="
        echo "[WARN] Could not determine physical ethernet interface to use for bridging br0"
        echo ""
        echo "No active ethernet interface was found. Please check your network configuration"
        echo "and make sure that an ethernet interface is set up as your primary network"
        echo "interface, and that it is connected to the internet."
        echo ""
        echo "It's possible that you're using a non-standard network interface (we expect"
        echo "eth0, em1, or en01)."
        echo ""
    fi
  else
    echo "Active network interface $primary_from_route found"
    ciab_nic_guess="$primary_from_route"
    active_nic="$primary_from_route"
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
  echo "eth0, em1, or en01)."
  echo ""
fi

echo "[Precheck] OK, network interfaces checked."
echo ""

# Check to see if the primary network interface is configured to use DHCP.
# If it is, warn and abort.
grep -i dhcp /etc/sysconfig/network-scripts/ifcfg-$active_nic
if [ "$?" == "0" ]; then
    echo "====="
    echo "WARNING: we recommend configuring Eucalypus servers to use"
    echo "a static IP address. This system is configured to use DHCP,"
    echo "which will cause problems if you lose the DHCP lease for this"
    echo "system."
    echo ""
    echo "Continue anyway? [y/N]"
    read continue_dhcp
    if [ "$continue_dhcp" = "n" ] || [ "$continue_dhcp" = "N" ] || [ -z "$continue_dhcp" ]
    then 
        echo "Stopped by user request."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=DHCP_NOT_RECOMMENDED&id=$uuid" >> /tmp/fsout.log
        exit 1
    fi
fi

echo "[Precheck] Precheck successful."
echo ""
echo ""

###############################################################################
# SECTION 2: USER INPUT
#
###############################################################################

# Attempt to prepopulate values
if [ $(ip addr show $active_nic | grep "inet" | grep -v 'inet6' | wc -l) -gt 1 ]; then
    echo ""
    echo "We found too many IP addresses bound to $active_nic; this is unsupported!"
    echo ""
    echo "Please remove any IP addresses that may have been bound to this device, and re-run this script..."
    exit 17
fi
ciab_ipaddr_guess=`ip addr show $active_nic | grep "inet" | grep -v 'inet6' | awk '{print $2}' | cut -d':' -f2 | cut -d'/' -f1`
ciab_gateway_guess=`/sbin/ip route | awk '/default/ { print $3 }'`
ciab_netmask_cidr=`ip addr show $active_nic | grep 'inet' | grep -v 'inet6' | awk '{print $2}' | cut -d':' -f2 | cut -d'/' -f2`

if [ "$ciab_netmask_cidr" -eq 16 ]; then
  ciab_netmask_guess="255.255.0.0"
elif [ "$ciab_netmask_cidr" -eq 24 ]; then
  ciab_netmask_guess="255.255.255.0"
elif [ "$ciab_netmask_cidr" -eq 25 ]; then
  ciab_netmask_guess="255.255.255.128"
elif [ "$ciab_netmask_cidr" -eq 30 ]; then
  ciab_netmask_guess="255.255.255.252"
elif [ "$ciab_netmask_cidr" -eq 32 ]; then
  ciab_netmask_guess="255.255.255.255"
fi

if [ "$ciab_netmask_guess" == "" ]; then
    echo ""
    echo "We cannot determine the NETMASK from the device $active_nic..."
    echo ""
    exit 19
fi

ciab_subnet_guess=`ipcalc -n $ciab_ipaddr_guess $ciab_netmask_guess | cut -d'=' -f2`
ciab_ntp_guess=`gawk '/^server / {print $2}' /etc/chrony.conf | head -1`

echo "====="
echo ""
echo "Welcome to the Faststart installer!"

if [ "$nc_install_only" == "1" ]; 
then
    echo ""
    echo "We're about to turn this system into a Eucalyptus node controller."
    echo ""
else
    echo ""
    echo "We're about to turn this system into a single-system Eucalyptus cloud."
    echo ""
fi
echo "Note: it's STRONGLY suggested that you accept the default values where"
echo "they are provided, unless you know that the values are incorrect."

echo ""
echo "What's the NTP server which we will update time from? ($ciab_ntp_guess)"
read ciab_ntp
[[ -z "$ciab_ntp" ]] && ciab_ntp=$ciab_ntp_guess
echo "NTP="$ciab_ntp
echo ""

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

# We only ask certain questions for CIAB installs. Thus, if
# we're only installing the NC, we'll skip the following questions.

if [ "$nc_install_only" == "0" ]; then
    echo "You must now specify a range of IP addresses that are free"
    echo "for Eucalyptus to use.  These IP addresses should not be"
    echo "taken up by any other machines, and should not be in any"
    echo "DHCP address pools.  Faststart will split this range into"
    echo "public and private IP addresses, which will then be used"
    echo "by Eucalyptus instances.  Please specify a range of at least"
    echo "10 IP addresses."
    echo ""

    ipsinrange=0

    until (( $ipsinrange==1 )); do

        ciab_ips1='';
        ciab_ips2='';

        echo "What's the first address of your available IP range?"
        until valid_ip $ciab_ips1; do
            read ciab_ips1
            valid_ip $ciab_ips1 || echo "Please provide a valid IP."
        done

        echo "What's the last address of your available IP range?"
        until valid_ip $ciab_ips2; do
            read ciab_ips2
            valid_ip $ciab_ips2 || echo "Please provide a valid IP."
        done

        ipsub1=$(echo $ciab_ips1 | cut -d'.' -f1-3)
        ipsub2=$(echo $ciab_ips2 | cut -d'.' -f1-3)

        if [ $ipsub1 == $ipsub2 ]; then
            # OK, subnets match
            iptail1=$(echo $ciab_ips1 | cut -d'.' -f4)
            iptail2=$(echo $ciab_ips2 | cut -d'.' -f4)
            if ! (("$iptail1+9" < "$iptail2")); then
                echo "Please provide a range of at least 10 IP addresses, with the second IP greater than the first."
            else
                publicend=$(($iptail1+(($iptail2-$iptail1)/2)))
                privatestart=$(($publicend+1))
                ciab_publicips1="$ipsub1.$iptail1"
                ciab_publicips2="$ipsub1.$publicend"
                ciab_privateips1="$ipsub1.$privatestart"
                ciab_privateips2="$ipsub1.$iptail2"
                echo "OK, IP range is good"
                echo "  Public range will be:   $ciab_publicips1 - $ciab_publicips2"
                echo "  Private range will be   $ciab_privateips1 - $ciab_privateips2"
                ipsinrange=1
            fi
        else
            echo "Subnets for IP range don't match, try again."
        fi

    done

    echo ""
    echo "Do you wish to install the optional load balancer and image"
    echo "management services? This add 10-15 minutes to the installation." 
    echo "Install additional services? [Y/n]"
    read continue_services
    if [ "$continue_services" = "n" ] || [ "$continue_services" = "N" ]
    then 
        echo "OK, additional services will not be installed."
        ciab_extraservices="false"
        echo ""
    else
        echo "OK, additional services will be installed."
        ciab_extraservices="true"
    fi
fi

###############################################################################
# SECTION 3: PREP Chef Artifacts
#
###############################################################################

# Check to see if chef-solo is installed
echo "[Chef] Checking if Chef Client is installed"
CHEF_VERSION="12.8.1"
which chef-solo
if [ "$?" != "0" ]; then
    echo "====="
    echo "[INFO] Chef not found. Installing Chef Client"
    echo ""
    echo ""
    curl --insecure -L https://omnitruck.chef.io/install.sh | bash -s -- -v $CHEF_VERSION 1>>$LOGFILE
    if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Chef install failed!"
        echo ""
        echo "Failed to install Chef. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=CHEF_INSTALL_FAILED&id=$uuid" >> /tmp/fsout.log
        exit 22
    fi
fi
echo "[Chef] OK, Chef Client is installed"
echo ""

echo "[Chef] Removing old Chef templates"
# Get rid of old Chef stuff lying about.
rm -rf /var/chef/* 1>>$LOGFILE

echo "[Chef] Downloading necessary cookbooks"
echo "[Chef] Downloading necessary cookbooks from URL: $cookbooks_url" >> $LOGFILE
# Grab cookbooks from git
yum install -y git 1>>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to install git!"
        echo ""
        echo "Failed to install git. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=GIT_INSTALL_FAILED&id=$uuid" >> /tmp/fsout.log
        exit 25
fi
rm -rf cookbooks
curl $cookbooks_url > cookbooks.tgz
tar zxfv cookbooks.tgz

# Copy the templates to the local directory
cp -f cookbooks/eucalyptus/faststart/ciab-template.json ciab.json
cp -f cookbooks/eucalyptus/faststart/node-template.json node.json

# Decide which template we're using.
if [ "$nc_install_only" == "0" ]; then
    chef_template="ciab.json"
else
    chef_template="node.json"
fi

# Perform variable interpolation in the proper template.
sed -i "s/IPADDR/$ciab_ipaddr/g" $chef_template
sed -i "s/NETMASK/$ciab_netmask/g" $chef_template
sed -i "s/GATEWAY/$ciab_gateway/g" $chef_template
sed -i "s/SUBNET/$ciab_subnet/g" $chef_template
sed -i "s/PUBLICIPS1/$ciab_publicips1/g" $chef_template
sed -i "s/PUBLICIPS2/$ciab_publicips2/g" $chef_template
sed -i "s/PRIVATEIPS1/$ciab_privateips1/g" $chef_template
sed -i "s/PRIVATEIPS2/$ciab_privateips2/g" $chef_template
sed -i "s/EXTRASERVICES/$ciab_extraservices/g" $chef_template
sed -i "s/NIC/$ciab_nic/g" $chef_template
sed -i "s/NTP/$ciab_ntp/g" $chef_template

if [ "$ciab_bridge_primary" -eq 1 ]; then
    echo ""
    echo "Binding Eucalyptus to device br0"
    echo ""
    sed -i "s/BINDINTERFACE/br0/g" $chef_template
else
    echo ""
    echo "Binding Eucalyptus to device $ciab_nic"
    echo ""
    sed -i "s/BINDINTERFACE/$ciab_nic/g" $chef_template
fi

###############################################################################
# SECTION 4: INSTALL EUCALYPTUS
#
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

if [ "$nc_install_only" == "0" ]; then
    if [ "$ciab_extraservices" == "true" ]; then
        echo ""
        echo "Your cloud-in-a-box should be installed in 30-45 minutes. Go have a cup of coffee!"
        echo ""
    else
        echo ""
        echo "Your cloud-in-a-box should be installed in 15-20 minutes. Go have a cup of coffee!"
        echo ""
    fi
else
    echo ""
    echo "Your node controller should be installed in a few minutes. Go have a cup of coffee!"
    echo ""
fi

# To make the spinner work, we need to launch in a subshell.  Since we 
# can't get variables from the subshell scope, we'll write success or
# failure to a file, and then succeed or fail based on whether the file
# exists or not.

rm -f faststart-successful*.log

echo "[Yum Update] OK, running a full update of the OS. This could take a bit; please wait."
echo ""
echo "To see the update in progress, run the following command in another terminal:"
echo ""
echo "  tail -f $LOGFILE"
echo ""
echo "[Yum Update] Package update in progress..."
yum -y update
if [ "$?" != "0" ]; then
    echo "====="
    echo "[FATAL] Yum update failed!"
    echo ""
    echo "Failed to do a full update of the OS. See $LOGFILE for details. /var/log/yum.log"
    echo "may also have some details related to the same."
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=FULL_YUM_UPDATE_FAILED&id=$uuid" >> /tmp/fsout.log
    exit 24
fi

#
# OK, THIS IS THE BIG STEP!  Install whichever chef template we're going with here.
# On successful exit, write "success" to faststart-successful*.log.

if [ "$nc_install_only" -eq 0 ]; then
  # add only the cloud-controller recipe to the run_list
  runlistitems="recipe[eucalyptus::cloud-controller]"
fi

# Execute phase 1 which adds only the cloud-controller recipe to the run_list
(chef-solo -r cookbooks.tgz -j $chef_template -o $runlistitems 1>>$LOGFILE && echo "Phase 1 success" > faststart-successful-phase1.log) &
coffee $!

if [[ ! -f faststart-successful-phase1.log ]]; then
    echo "[FATAL] Eucalyptus installation failed"
    echo ""
    echo "Eucalyptus installation failed. Please consult $LOGFILE for details."
    echo ""
    echo "Please try to run the installation again. If your installation fails again,"
    echo "you can ask the Eucalyptus community for assistance:"
    echo ""
    echo "https://groups.google.com/a/eucalyptus.com/forum/#!forum/euca-users"
    echo ""
    echo "Or find us on IRC at irc.freenode.net, on the #eucalyptus channel."
    echo ""
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=EUCA_INSTALL_FAILED&id=$uuid" >> /tmp/fsout.log
    offer_support "EUCA_INSTALL_FAILED"
    exit 99
  else
    echo "Phase 1 (CLC) installed successfully...getting a 2nd cup of coffee and moving on to phase 2 (main cloud components)."
fi

# Add all other recipes to the run_list and execute phase 2
if [ "$nc_install_only" -eq 0 ]; then
  runlistitems=""
  runlistitems="recipe[eucalyptus::user-console]"
  runlistitems="$runlistitems,recipe[eucalyptus::register-components]"
  runlistitems="$runlistitems,recipe[eucalyptus::walrus]"
  runlistitems="$runlistitems,recipe[eucalyptus::cluster-controller]"
  runlistitems="$runlistitems,recipe[eucalyptus::storage-controller]"
  runlistitems="$runlistitems,recipe[eucalyptus::node-controller]"
  runlistitems="$runlistitems,recipe[eucalyptus::configure]"
fi

(chef-solo -r cookbooks.tgz -j $chef_template -o $runlistitems 1>>$LOGFILE && echo "Phase 2 success" > faststart-successful-phase2.log) &
coffee $!

if [[ ! -f faststart-successful-phase2.log ]]; then
    echo "[FATAL] Eucalyptus installation failed"
    echo ""
    echo "Eucalyptus installation failed. Please consult $LOGFILE for details."
    echo ""
    echo "Please try to run the installation again. If your installation fails again,"
    echo "you can ask the Eucalyptus community for assistance:"
    echo ""
    echo "https://groups.google.com/a/eucalyptus.com/forum/#!forum/euca-users"
    echo ""
    echo "Or find us on IRC at irc.freenode.net, on the #eucalyptus channel."
    echo ""
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=EUCA_INSTALL_FAILED&id=$uuid" >> /tmp/fsout.log
    offer_support "EUCA_INSTALL_FAILED"
    exit 99
  else
    echo "Phase 2 installed successfully...yes, in fact having that 3rd cup of coffee and moving on to phase 3 (create first resources)."
fi

# add create first resources as a last item
if [ "$nc_install_only" -eq 0 ]; then
  runlistitems=""
  runlistitems="recipe[eucalyptus::create-first-resources]"
fi

(chef-solo -r cookbooks.tgz -j $chef_template -o $runlistitems 1>>$LOGFILE && echo "Phase 3 success" > faststart-successful-phase3.log) &
coffee $!

if [[ ! -f faststart-successful-phase3.log ]]; then
    echo "[FATAL] Eucalyptus installation failed"
    echo ""
    echo "Eucalyptus installation failed. Please consult $LOGFILE for details."
    echo ""
    echo "Please try to run the installation again. If your installation fails again,"
    echo "you can ask the Eucalyptus community for assistance:"
    echo ""
    echo "https://groups.google.com/a/eucalyptus.com/forum/#!forum/euca-users"
    echo ""
    echo "Or find us on IRC at irc.freenode.net, on the #eucalyptus channel."
    echo ""
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=EUCA_INSTALL_FAILED&id=$uuid" >> /tmp/fsout.log
    offer_support "EUCA_INSTALL_FAILED"
    exit 99
fi



###############################################################################
# SECTION 5: POST-INSTALL CONFIGURATION
#
# If we reach this section, install has been successful. Take two different
# paths: one for the NC mode, another for the CIAB mode.
###############################################################################

if [ "$nc_install_only" == "0" ]; then

#
# FINISH CLOUD-IN-A-BOX INSTALL
#

    echo ""
    echo "[Config] Generating credentials"

    echo ""
    echo "[Config] Enabling web console"
    euare-useraddloginprofile --as-account eucalyptus -u admin -p password

    echo "[Config] Adding ssh and http to default security group"
    euca-authorize -P tcp -p 22 default
    euca-authorize -P tcp -p 80 default

    echo ""
    echo ""
    echo "[SUCCESS] Eucalyptus installation complete!"
    total_time=$(timer $t)
    printf 'Time to install: %s\n' $total_time
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=EUCA_INSTALL_SUCCESS&id=$uuid" >> /tmp/fsout.log

    # Add links to the /etc/motd file
    tutorial_path=`pwd`
    cat << EOF > /etc/motd

 _______                   _
(_______)                 | |             _
 _____   _   _  ____ _____| |_   _ ____ _| |_ _   _  ___
|  ___) | | | |/ ___|____ | | | | |  _ (_   _) | | |/___)
| |_____| |_| ( (___/ ___ | | |_| | |_| || |_| |_| |___ |
|_______)____/ \____)_____|\_)__  |  __/  \__)____/(___/
                            (____/|_|

To log in to the Management Console, go to:
https://${ciab_ipaddr}/

Default User Credentials (unless changed):
  * Account: eucalyptus
  * Username: admin
  * Password: password

Eucalyptus CLI Tutorials can be found at:

  $tutorial_path/cookbooks/eucalyptus/faststart/tutorials

EOF

    echo "To log in to the Management Console, go to:"
    echo "https://${ciab_ipaddr}/"
    echo ""
    echo "User Credentials:"
    echo "  * Account: eucalyptus"
    echo "  * Username: admin"
    echo "  * Password: password"
    echo ""

    echo "If you are new to Eucalyptus, we strongly recommend that you run"
    echo "the Eucalyptus tutorial now:"
    echo ""
    echo "  cd $tutorial_path/cookbooks/eucalyptus/faststart/tutorials"
    echo "  ./master-tutorial.sh"
    echo ""
    echo "Thanks for installing Eucalyptus!"

else
#
# NODE CONTROLLER INSTALL SUCCESSFUL
#
    echo ""
    echo ""
    echo "[SUCCESS] Eucalyptus node controller installation complete!"
    total_time=$(timer $t)
    printf 'Time to install: %s\n' $total_time
    echo ""
    echo "Now, to register your node controller with your cloud, ssh to your"
    echo "cloud-in-a-box server and run the following command:"
    echo ""
    echo "  clusteradmin-register-nodes ${ciab_ipaddr}"
    echo ""
    echo "Finally copy keys to the node controller from the cloud-in-a-box server:"
    echo "  clusteradmin-copy-keys ${ciab_ipaddr}"
    echo ""
    echo "Thanks for installing Eucalyptus!"
    curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=NC_INSTALL_SUCCESS&id=$uuid" >> /tmp/fsout.log

fi

exit 0
