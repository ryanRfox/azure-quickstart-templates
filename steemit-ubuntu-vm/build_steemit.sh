#!/bin/bash

set -x
date
ps axjf

NPROC=$(nproc)
INSTALL_METHOD=$1
USER_NAME=$2
DESIRED_NAME=$3

printf '%s\n%s\n' 'USER_NAME=$USER_NAME' 'DESIRED_NAME=$DESIRED_NAME' >> /home/$USER_NAME/steem_install.log
