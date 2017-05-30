#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
ACCOUNT_NAMES=$3
NPROC=$(nproc)
LOCAL_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8090
P2P_PORT=1776
PROJECT=eos
GITHUB_REPOSITORY=https://github.com/eosio/eos.git
WITNESS_NODE=eos_producer_node
CLI_WALLET=eosd

echo "USER_NAME: $USER_NAME"
echo "ACCOUNT_NAMES : $ACCOUNT_NAMES"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $LOCAL_IP"
echo "P2P_PORT: $P2P_PORT"
echo "RPC_PORT: $RPC_PORT"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "PROJECT: $PROJECT"
echo "WITNESS_NODE: $WITNESS_NODE"
echo "CLI_WALLET: $CLI_WALLET"

echo "Begin Update..."
sudo apt-get -y update || exit 1;
# To avoid intermittent issues with package DB staying locked when next apt-get runs
sleep 5;

##################################################################################################
# Clone the project from the source repository. Initialize the project.                          #
##################################################################################################
echo "Clone $PROJECT project"
cd /usr/local/src
time git clone $GITHUB_REPOSITORY
cd $PROJECT
time git submodule update --init --recursive

##################################################################################################
# Install all necessary packages for building the project.                                       #
##################################################################################################
time apt -y install ntp g++ make cmake libbz2-dev libssl-dev autoconf automake libtool \
                    pkg-config libboost-all-dev libreadline-dev doxygen libncurses5-dev

##################################################################################################
# Build the project.                                                                             #
##################################################################################################
cd /usr/local/src/$PROJECT/
time cmake -DCMAKE_BUILD_TYPE=Debug .
time make -j$NPROC

##################################################################################################
# Configure graphene service. Enable it to start on boot.                                        #
##################################################################################################
cat >/lib/systemd/system/$PROJECT.service <<EOL
[Unit]
Description=Job that runs $PROJECT daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/$PROJECT/producer_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/$PROJECT/producer_node
ExecStart=/usr/bin/$WITNESS_NODE --data-dir /home/$USER_NAME/$PROJECT/producer_node
TimeoutSec=300
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable $PROJECT
service $PROJECT start

##################################################################################################
# TODO: Directions to connect to wallet and interact with network.                               #
##################################################################################################
