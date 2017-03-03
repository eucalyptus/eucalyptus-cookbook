#!/bin/bash

# TODOs:
#   + Remove the raw image file after successful install.
#   + Add some websites where users can find images.

bold=`tput bold`
normal=`tput sgr0`

region=`grep domain ../../../../ciab.json | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}.nip.io'`
if [ "${region}" = "" ]
then
    echo "ERROR: Cannot determine region from file ../../../../ciab.json"
    echo "Please verify that this tutorial is being run in the directory "
    echo "/root/cookbooks/eucalyptus/faststart/tutorials where we expect it to"
    echo "be run."
    exit 1
fi

echo ""
echo ""
echo "${bold}Installing Images${normal}"
echo ""
echo "Continue with Installing Images Tutorial? (Y/n)"

read continue
if [ "$continue" = "n" ] || [ "$continue" = "N" ]
then
    echo "OK. To run though this tutorial at any time, run the following command: "
    echo "  $0"
    exit 1
fi

echo "The default image installed by Faststart is small, and"
echo "not useful for much beyond demonstrating how images work."
echo ""
echo "In this tutorial, we will download a cloud image"
echo "from the internet and install it on your Faststart"
echo "cloud."
echo ""
echo "Hit Enter to continue."

read continue

echo "Many Linux distributions now have preconfigured cloud images, so"
echo "you can download and install them to your cloud easily. For this"
echo "tutorial we will add a Fedora 20 cloud image to your cloud."
echo ""
echo "First, we will download and the image with curl. Eucalyptus"
echo "accepts raw images by default, so we will download a"
echo "compressed, raw image."
echo ""
echo "Hit Enter to download the image with curl. (Note: it may take a while.)"

read continue

echo "+ ${bold}curl http://mirror.fdcservers.net/fedora/updates/20/Images/x86_64/Fedora-x86_64-20-20140407-sda.raw.xz > fedora.raw.xz${normal}"
curl http://mirror.fdcservers.net/fedora/updates/20/Images/x86_64/Fedora-x86_64-20-20140407-sda.raw.xz > fedora.raw.xz

# Fail if the image download fails
if [ "$?" != "0" ]; then
    echo "======"
    echo "[OOPS] Curl failed!"
    echo ""
    echo "It appears that curl failed to fetch the image. Please check"
    echo "your network connection and try the tutorial again."
    echo ""
    echo "Exiting..."
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?/msg=TT_DOWNLOAD_IMAGE_FAILED&uuid=$uuid" >> /dev/null
    exit 1
fi

echo ""
echo "OK, now let's unzip the image. This image is zipped in the xz"
echo "format, so to unzip the image, we will use the ${bold}xz${normal} command."
echo ""
echo "Hit Enter to unzip the image. (This may also take a bit.)"

# Unzip the image.

read continue
echo "+ ${bold}xz -d fedora.raw.xz${normal}"
xz -d fedora.raw.xz

echo ""
echo "OK, now you are ready to install the image into your cloud."
echo "To install the image, we will run the following command:"
echo ""
echo "${bold}euca-install-image -n Fedora20 -b tutorial -i fedora.raw -r x86_64 --virtualization-type hvm --region admin@${region}${normal}"
echo ""
echo "  ${bold}-n Fedora20${normal} specifies the name we're giving the image."
echo "  ${bold}-b tutorial${normal} specifies the bucket we're putting the image into."
echo "  ${bold}-i fedora.raw${normal} specifies the filename of the input image."
echo "  ${bold}-r x86_64${normal} specifies the architecture of the image."
echo "  ${bold}--virtualization-type hvm${normal} means that we're using a native hvm image."
echo ""
echo "Hit Enter to install the image."

read continue

# Install the image.
echo "+ ${bold}euca-install-image -n Fedora20 -b tutorial -i fedora.raw -r x86_64 --virtualization-type hvm --region admin@${region}${normal}"
euca-install-image -n Fedora20 -b tutorial -i fedora.raw -r x86_64 --virtualization-type hvm --region admin@${region}
if [ "$?" != "0" ]; then
    echo "======"
    echo "[OOPS] euca-install-image failed!"
    echo ""
    echo "It appears that Eucalyptus failed to install the image. You may want to"
    echo "check to see if you have enough disk space to install this image."
    echo ""
    echo "Exiting..."
    curl --silent "https://www.eucalyptus.com/faststart_errors.html?/msg=TT_INSTALL_IMAGE_FAILED&uuid=$uuid" >> /dev/null
    exit 1
fi

echo ""
echo "By default, your machine images are visible only to you. You may"
echo "easily make images available to other cloud users. Let's make"
echo "your new image available to all users of this cloud."
echo ""
echo "Hit Enter to modify the image attribute."

read continue

# get the EMI_ID
EMI_ID=$(euca-describe-images --region admin@${region} | grep tutorial | tail -n 1 | grep emi | cut -f 2)
echo "+ ${bold}euca-modify-image-attribute -l -a all $EMI_ID --region admin@${region}${normal}"
euca-modify-image-attribute -l -a all $EMI_ID --region admin@${region}

echo ""
echo "Your new Fedora machine image is installed and available to all"
echo "users on your cloud! Let's confirm that by running euca-describe-images"
echo "one more time."
echo ""
echo "Hit Enter to show the list of images."

read continue

echo "+ ${bold}euca-describe-images --region admin@${region}${normal}"
euca-describe-images --region admin@${region}

echo ""
