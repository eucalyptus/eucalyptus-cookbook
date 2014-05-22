#!/bin/bash

bold=`tput bold`
normal=`tput sgr0`

# Skip code
if false; then

echo ""
echo ""
echo "${bold}A Brief Image Tutorial${normal}"
echo ""
echo "Hit Enter to continue."

read continue

echo "The fundamental building block of Eucalyptus is the image,"
echo "and we use euca2ools to interact with those images."
echo ""
echo "In this tutorial, we're going to show you how to list"
echo "the images available to your Eucalyptus users."
echo ""
echo "Hit Enter to continue."

read continue

echo "Remember: when using Eucalyptus, you must \"log in\"."
echo "When using euca2ools, the way to \"log in\" is to source"
echo "the euca2ools credentials file. By default, Faststart"
echo "installs your credentials fule in the root directory."
echo ""
echo "Hit Enter to run the command:"
echo "  ${bold}source /root/eucarc${normal}"

read continue
echo "${bold}+ source /root/eucarc${normal}"


# Unskip code
fi

source /root/eucarc

echo "The euca2ools command for listing images is ${bold}euca-describe-images${normal}."
echo "If you have ever worked with Amazon Web Services, you will"
echo "notice that the command, and the output from the command, is"
echo "nearly identical to the comparable AWS command; this is by design."
echo "Press Enter to run ${bold}euca-describe-images${normal} now."

read continue
echo "${bold}+ euca-describe-images"
euca-describe-images
echo "${normal}"

echo "Now let's review some of the key output of that command:"
echo ""
imagelist=`euca-describe-images | tail -n 1`
imageid=`echo $imagelist | awk '{print $2}'`
imagepath=`echo $imagelist | awk '{print $3}'`
public=`echo $imagelist | awk '{print $6}'`
echo "  ${bold}${imageid}${normal} is the ${bold}image ID${normal}, which is used" 
echo "  to refer to the image by most other commands."
echo ""
echo "  ${bold}${imagepath}${normal} is the image path."
echo ""
echo "  ${bold}${public}${normal} is the permission for this image. Images that"
echo "  are accessible to all users of this cloud are marked public; images that can"
echo "  only be run by the owner of the image are marked private."
echo "" 

echo "To learn more about the euca-describe-images command, check out the documentaion:"
echo "  https://www.eucalyptus.com/docs/eucalyptus/3.4/index.html#euca2ools-guide/euca-describe-images.html"

