#!/bin/bash

IMGS=(
"
   ( (     \n\
    ) )    \n\
  ........ \n\
  |      |]\n\
  \      / \n\
   ------  \n
" "
   ) )     \n\
    ( (    \n\
  ........ \n\
  |      |]\n\
  \      / \n\
   ------  \n
" )
IMG_REFRESH="0.5"
LINES_PER_IMG=$(( $(echo $IMGS[0] | sed 's/\\n/\n/g' | wc -l) + 1 ))
tput_loop() { for((x=0; x < $LINES_PER_IMG; x++)); do tput $1; done; }

coffee() 
{
    local pid=$1
    IFS='%'
    tput civis
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do for x in "${IMGS[@]}"; do
        echo -ne $x
        tput_loop "cuu1"
        sleep $IMG_REFRESH
    done; done
    tput_loop "cud1"
    tput cvvis
}

rm -f faststart-successful.log
(./fail-script.sh && echo "success" > faststart-successful.log) &
coffee $!

if [[ ! -f faststart-successful.log ]]; then
    echo "[FATAL] Eucalyptus installation failed"
    echo ""
    echo "Eucalyptus installation failed. Please consult $LOGFILE for details."
    exit 99
fi

