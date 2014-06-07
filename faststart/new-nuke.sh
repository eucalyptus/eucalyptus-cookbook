#!/bin/bash

###############################################################################
#  Command-line script for nuking any Euca installation. USE WITH CAUTION.
###############################################################################

# Create uuid
uuid=`uuidgen -t`
LOGFILE='/var/log/euca-nuke-'`date +%m.%d.%Y-%H.%M.%S`'.log'

###############################################################################
# SECTION 1: PRECHECK.
# 
# Any immediately diagnosable condition that might prevent Euca from being
# properly installed should be checked here.
###############################################################################

# WARNING: if you're running on a laptop, turn sleep off in BIOS!
# Sleep can affect VMs badly.

echo ""
echo "NOTE: you're about to blow away your Eucalyptus installation."
echo "That means removing all trace of Eucalyptus from this system."
echo "What is done cannot be undone."
echo ""
echo "Are you really super sure that you want to do this? [y/N]"

read continue_nuke
if [ "$continue_nuke" = "n" ] || [ "$continue_nuke" = "N" ] || [ -z "$continue_nuke" ]
then 
    echo "Stopped by user request."
    exit 1
fi

echo "[Precheck] Checking root"
ciab_user=`whoami`
if [ "$ciab_user" != 'root' ]; then
    echo "======"
    echo "[FATAL] Not running as root"
    echo ""
    echo "Please run the nuke command as the root user."
    exit 5
fi
echo "[Precheck] OK, running as root"
echo ""

curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=NUKE_START&id=$uuid" >> /tmp/fsout.log

# Check to see if chef-solo is installed
echo "[Precheck] Checking if Chef Client is installed"
which chef-solo
if [ "$?" != "0" ]; then
    echo "====="
    echo "[INFO] Chef not found. Installing Chef Client"
    echo ""
    echo ""
    curl -L https://www.opscode.com/chef/install.sh | bash 1>>"$LOGFILE"
    if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Chef install failed!"
        echo ""
        echo "Chef is required to run Nuke, and we were unable to install Chef. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=CHEF_INSTALL_FAILED&uuid=$uuid" >> /tmp/fsout.log
        exit 22
    fi
fi
echo "[Precheck] OK, Chef Client is installed"
echo ""

echo "[Prep] Removing old Chef templates"
# Get rid of old Chef stuff lying about.
rm -rf /var/chef/* 1>>$LOGFILE

echo "[Prep] Downloading necessary cookbooks"
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
mkdir -p cookbooks
pushd cookbooks
git clone https://github.com/eucalyptus/eucalyptus-cookbook eucalyptus 1>>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch Eucalyptus cookbook!"
        echo ""
        echo "Failed to fetch Eucalyptus cookbook. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=GIT_CLONE_EUCA_FAILED&id=$uuid" >> /tmp/fsout.log
        exit 25
fi
git clone https://github.com/opscode-cookbooks/yum 1>>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch yum cookbook!"
        echo ""
        echo "Failed to fetch yum cookbook. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=GIT_CLONE_YUM_FAILED&id=$uuid" >> /tmp/fsout.log
        exit 25
fi
git clone https://github.com/opscode-cookbooks/ntp 1>>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch ntp cookbook!"
        echo ""
        echo "Failed to fetch ntp cookbook. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=GIT_CLONE_NTP_FAILED&id=$uuid" >> /tmp/fsout.log
        exit 25
fi
git clone https://github.com/opscode-cookbooks/selinux 1>>$LOGFILE
if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Failed to fetch selinux cookbook!"
        echo ""
        echo "Failed to fetch selinux cookbook. See $LOGFILE for details."
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=GIT_CLONE_SELINUX_FAILED&id=$uuid" >> /tmp/fsout.log
        exit 25
fi
popd

echo "[Prep] Tarring up cookbooks"
# Tar up the cookbooks for use by chef-solo.
tar czvf cookbooks.tgz cookbooks 1>>$LOGFILE

echo "Nuking Eucalyptus install"
chef-solo -r cookbooks.tgz -j cookbooks/eucalyptus/faststart/nuke.json 1>>$LOGFILE

if [ "$?" != "0" ]; then
        echo "====="
        echo "[FATAL] Nuke failed!"
        echo ""
        echo "Something went wrong during the nuke process."
        echo "For details, check the log: $LOGFILE"
        echo ""
        curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=NUKE_FAILED&id=$uuid" >> /tmp/fsout.log
        exit 25
fi

echo ""
echo "Eucalyptus nuked."
curl --silent "https://www.eucalyptus.com/docs/faststart_errors.html?msg=NUKE_SUCCESSFUL&id=$uuid" >> /tmp/fsout.log
