#!/bin/bash

bold=`tput bold`
normal=`tput sgr0`

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
echo "That's all for now. Check back for new tutorials by running the"
echo "following command from this directory:"
echo ""
echo "git pull"
echo ""
echo "Thanks for trying Eucalyptus!"
echo ""
echo ""
