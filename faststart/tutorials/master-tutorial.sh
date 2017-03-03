#!/bin/bash

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
echo "*****"
echo ""
echo "Welcome to the Getting Started Tutorial.  We will walk you through"
echo "some of the key concepts of managing your new Eucalyptus cloud."
echo "It is ${bold}strongly recommended${normal} for first-time users of Eucalyptus."
echo ""
echo "Would you like to walk through the Getting Started tutorial? [Y/n]"
read continue
if [ "$continue" = "n" ] || [ "$continue" = "N" ]
then
    echo "OK. To run though the full tutorial at any time, run the following command: "
    echo "  $0"
    echo ""
    echo "You may also choose to run any of the individual tutorial scripts"
    echo "in the tutorial/ directory at any time."
    exit 1
fi

./describe-images.sh
./install-image.sh

echo ""
echo "* * * * *"
echo ""
echo "That's all for now."
echo ""
echo "You can try launching the image we just installed by running the "
echo "\'launch-instance.sh\' script next."
echo ""
echo "Thanks for trying Eucalyptus!"
echo ""
echo ""
