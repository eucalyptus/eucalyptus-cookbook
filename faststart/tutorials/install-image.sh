#!/bin/bash

bold=`tput bold`
normal=`tput sgr0`

echo ""
echo ""
echo "${bold}Installing Images${normal}"
echo ""
echo "Hit Enter to continue."

read continue

echo "The image installed with Faststart is small, and"
echo "not useful for much beyond demonstrating how"
echo "images work."
echo ""
echo "In this tutorial, we will download a cloud image"
echo "from the internet and install it on your Faststart"
echo "cloud."
echo ""
echo "Hit Enter to continue."

read continue

source /root/eucarc


echo "Many Linux distributions now have preconfigured cloud images, so"
echo "you can download and install them to your cloud easily. For this"
echo "tutorial we will add a Fedora 20 cloud image to your cloud."
echo ""
echo "Hit Enter to download an unpack the image"

read continue
# Download the image
echo "${bold}curl http://mirror.fdcservers.net/fedora/updates/20/Images/x86_64/Fedora-x86_64-20-20140407-sda.raw.xz > fedora.raw.xz${normal}"
curl http://mirror.fdcservers.net/fedora/updates/20/Images/x86_64/Fedora-x86_64-20-20140407-sda.raw.xz > fedora.raw.xz

# Unzip the image.
echo "${bold}xz -d fedora.raw.xz${normal}"
xz -d fedora.raw.xz

echo ""
echo "Now you are ready to install the image into your cloud."
echo "Hit Enter to install the image"
echo ""

read continue

# Install the image.
echo "${bold}euca-install-image -n Fedora20 -b fedora -i fedora.raw -r x86_64 --virtualization-type hvm${normal}"
euca-install-image -n Fedora20 -b fedora -i fedora.raw -r x86_64 --virtualization-type hvm


echo ""
echo "By default, your machine images are visible only to you. You may"
echo "easily make images available to other cloud users. Let's make"
echo "your new image available to all users of this cloud."
echo ""
echo "Hit Enter to modify the image attribute"
echo ""
# get the EMI_ID
EMI_ID=$(euca-describe-images | grep fedora | grep emi | cut -f 2)
echo "euca-modify-image-attribute -l -a all $EMI_ID"
echo euca-modify-image-attribute -l -a all $EMI_ID

echo ""
echo "Your new fedora machine image is installed and available to all"
echo "user on your cloud."
echo ""


