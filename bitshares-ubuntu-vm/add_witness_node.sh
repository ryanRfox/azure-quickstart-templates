#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
WITNESS_ID=$3
NPROC=$(nproc)
LOCAL_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8090
P2P_PORT=1776
GITHUB_REPOSITORY=https://github.com/bitshares/bitshares-core.git
BUILD_TYPE=Release
PROJECT=bitshares-core
WITNESS_NODE=bts-witness
CLI_WALLET=bts-cli_wallet

echo "USER_NAME: $USER_NAME"
echo "WITNESS_ID : $WITNESS_ID"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $LOCAL_IP"
echo "P2P_PORT: $P2P_PORT"
echo "RPC_PORT: $RPC_PORT"
echo "SEED_NODE: $SEED_NODE"
echo "PROJECT: $PROJECT"
echo "WITNESS_NODE: $WITNESS_NODE"
echo "CLI_WALLET: $CLI_WALLET"

sudo apt-get -y update || exit 1;
# To avoid intermittent issues with package DB staying locked when next apt-get runs
sleep 5;

##################################################################################################
# Clone the python-bitshares project from the Xeroc source repository.                           #
##################################################################################################
apt -y install libffi-dev libssl-dev python-dev python3-pip
pip3 install pip --upgrade
cd /usr/local/src
time git clone https://github.com/xeroc/python-bitshars.git
cd python-bitshares
pip3 install autobahn pycrypto graphenelib 
python3 setup.py install --user

##################################################################################################
# Download the pre-compiled witness_node and cli_wallet provided by the trusted source for this  #
# the GRAPHENE TEST.                                                                             #
##################################################################################################
#cd  /usr/bin/
#time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/$WITNESS_NODE
#chmod +x $WITNESS_NODE
#
#time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/$CLI_WALLET
#chmod +x $CLI_WALLET
#
#mkdir /home/$USER_NAME/key_gen
#cd /home/$USER_NAME/key_gen
#time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/testnet_cli_wallet
#chmod +x testnet_cli_wallet

##################################################################################################
# Update Ubuntu and install prerequisites for running BitShares                                  #
##################################################################################################
time apt-get -y install ntp g++ git make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev \
                        openssl libreadline-dev autoconf libtool libboost-all-dev

##################################################################################################
# Build BitShares from source                                                                    #
##################################################################################################
cd /usr/local
time git clone $GITHUB_REPOSITORY
cd $PROJECT
time git submodule update --init --recursive
time cmake -DCMAKE_BUILD_TYPE=$RELEASE_TYPE .
time make -j$NPROC

cp /usr/local/$PROJECT/programs/witness_node/witness_node /usr/bin/$WITNESS_NODE
cp /usr/local/$PROJECT/programs/cli_wallet/cli_wallet /usr/bin/$CLI_WALLET

##################################################################################################
# Configure bitshares-core service. Enable it to start on boot.                                  #
##################################################################################################
cat >/lib/systemd/system/$PROJECT.service <<EOL
[Unit]
Description=Job that runs $PROJECT daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/$PROJECT/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/$PROJECT/witness_node
ExecStart=/usr/bin/$WITNESS_NODE --data-dir /home/$USER_NAME/$PROJECT/witness_node

TimeoutSec=300
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable $PROJECT
service $PROJECT start
service $PROJECT stop
