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

echo "And now we do stuff."
echo ""

echo "To learn more about the euca-install-image command, check out the docs:"
echo "  FIXME"

