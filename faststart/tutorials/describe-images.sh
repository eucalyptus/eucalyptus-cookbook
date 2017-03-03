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
echo ""
echo "${bold}Listing Images${normal}"
echo ""
echo "Continue with Listing Images Tutorial? (Y/n)"

read continue
if [ "$continue" = "n" ] || [ "$continue" = "N" ]
then
    echo "OK. To run though this tutorial at any time, run the following command: "
    echo "  $0"
    exit 1
fi

echo "The fundamental building block of Eucalyptus is the image."
echo "We use a program called euca2ools to interact with those images."
echo ""
echo "In this tutorial, we're going to show you how to list"
echo "the images available to your Eucalyptus users."
echo ""
echo "Hit Enter to continue."

read continue

echo "Remember: when using Eucalyptus, you must \"log in\"."
echo "When using euca2ools, the way to \"log in\" is to use"
echo "the euca2ools configuration credentials file located"
echo "under /root/.euca. By default, Faststart sets this"
echo "configuration file up for you. Once this has been"
echo "set up, with each euca2ools command, the"
echo "\"--region\" option must be used. For FastStart,"
echo "the region option will contain the value"
echo "\"admin@${region}\".  For example:"
echo ""
echo "${bold}euca-describe-availability-zones --region admin@${region}${normal}"
echo ""
echo "To learn more about using euca2ools configuration file, please refer to"
echo "the Euca2ools Guide section entitled \"Working with Euca2ools Configuration Files\":"
echo "  http://docs.hpcloud.com/eucalyptus/4.2.0/#shared/euca2ools_working_with_config_files.html"

read continue

echo "The euca2ools command for listing images is ${bold}euca-describe-images${normal}."
echo "If you have ever worked with Amazon Web Services, you will"
echo "notice that the command, and the output from the command, is"
echo "nearly identical to the comparable AWS command; this is by design."
echo "Press Enter to run ${bold}euca-describe-images --region admin@${region}${normal} now."

read continue

echo "${bold}+ euca-describe-images --region admin@${region}"
euca-describe-images --region admin@${region}
echo "${normal}"

echo "Now let's review some of the key output of that command:"
echo ""
imagelist=`euca-describe-images --region admin@${region}| tail -n 1`
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
echo "  http://docs.hpcloud.com/eucalyptus/4.2.0/#euca2ools-guide/euca-describe-images.html"
