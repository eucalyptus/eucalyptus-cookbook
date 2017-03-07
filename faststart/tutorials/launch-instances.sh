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
echo "${bold}Launching Instances${normal}"
echo ""
echo "Continue with Installing Images Tutorial? (Y/n)"

read continue
if [ "$continue" = "n" ] || [ "$continue" = "N" ]
then
    echo "OK. To run though this tutorial at any time, run the following command: "
    echo "  $0"
    exit 1
fi

# Be sure the tutorial image is installed
EMI_ID=$(euca-describe-images --region admin@${region} | grep tutorial | grep emi | tail -n 1 | cut -f 2)

echo "In order to run the instance, we must know the EMI.  It can be found by running the command:"
echo ""
echo "${bold}euca-describe-images --region admin@${region} | grep tutorial | grep emi${normal}"

echo ""
echo "EMI ID is: $EMI_ID"

if [ "$EMI_ID" == "" ]
then
   echo "Unable to find the Fedora machine image. Use this command to install it:"
   echo "  tutorials/install-image"
   echo ""
   echo "Exiting..."
   exit 1
fi

echo ""

echo "${bold}euca-run-instances --show-empty-fields -k my-first-keypair $EMI_ID --region admin@${region}${normal}"
euca-run-instances --show-empty-fields -k my-first-keypair $EMI_ID --region admin@${region} | tee run_instance_output.txt

echo ""
echo "From the euca-run-instances command above, the important information is the Instance ID"
echo "and the public IP address of the instance."
echo ""
echo "The Instance ID is the 2nd field, and the public IP address is the 17th field. For reference, they are:"

# Capture the instance ID and public address
INSTANCE_ID=$(cat run_instance_output.txt | grep INSTANCE | cut -f2)
INSTANCE_ADDR=$(cat run_instance_output.txt | grep INSTANCE | cut -f17)

echo ""
echo "Instance ID: $INSTANCE_ID"
echo "IP Address: $INSTANCE_ADDR"
echo ""

rm run_instance_output.txt

# Wait up to 30 seconds for the instance to start.
echo "Waiting for your instance to start"
TIMER=0
STATUS=
while [ $TIMER -le 5 ]
do
   sleep 5
   STATUS=$(euca-describe-instances $INSTANCE_ID --region admin@${region} | grep $EMI_ID | grep running)
   [ "$STATUS" != "" ] && break;
   TIMER=$(( $TIMER + 1 ))
   echo $TIMER
done

# Congratulations! You can now connect to your instance
echo "Use this command to log into your new instance"
echo ""
echo " ssh -i ~/my-first-keypair.pem fedora@$INSTANCE_ADDR"
echo ""
