#!/bin/bash

bold=`tput bold`
normal=`tput sgr0`

echo ""
echo ""
echo "${bold}Launching Instances${normal}"
echo ""
echo "Hit Enter to continue."

read continue

# Be sure the tutorial image is installed
EMI_ID=$(euca-describe-images | grep tutorial | grep emi | tail -n 1 | cut -f 2)
if [ "$EMI_ID" == "" ]
then
   echo "Unable to find the Fedora machine image. Use this command to install it:"
   echo "  tutorials/install-image"
   exit 1
fi

source /root/eucarc


echo "${bold}euca-run-instances -k my-first-keypair $EMI_ID${normal}"
euca-run-instances -k my-first-keypair $EMI_ID

# Capture the instance ID and public address
echo "Capturing the instance ID"
INSTANCE_ID=$(euca-describe-instances | grep $EMI_ID | grep -v terminated | cut -f2)
echo "Capturing the public ip address"
INSTANCE_ADDR=$(euca-describe-instances | grep $INSTANCE_ID | cut -f4)


# Wait up to 30 seconds for the instance to start.
echo "Waiting for your instance to start"
TIMER=0
STATUS=
while [ $TIMER -le 5 ]
do
   sleep 5
   STATUS=$(euca-describe-instances $INSTANCE_ID | grep $EMI_ID | grep running)
   [ "$STATUS" != "" ] && break;
   TIMER=$(( $TIMER + 1 ))
   echo $TIMER
done

# Congratulations! You can now connect to your instance
echo "Use this command to log into your new instance"
ehco ""
echo " ssh -i ~/my-first-keypair.pem fedora@$INSTANCE_ADDR"
echo ""
