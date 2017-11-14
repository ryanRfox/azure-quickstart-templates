#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
WITNESS_NAMES=$3
NPROC=$(nproc)
LOCAL_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8090
P2P_PORT=1776
GITHUB_REPOSITORY=https://github.com/bitshares/bitshares-core.git
PROJECT=bitshares-core
BRANCH=$4
BUILD_TYPE=Release
WITNESS_NODE=bts-witness
CLI_WALLET=bts-cli_wallet
PUBLIC_BLOCKCHAIN_SERVER=wss://bitshares.openledger.info/ws
TRUSTED_BLOCKCHAIN_DATA=https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/bitshares-blockchain.tar.gz

echo "USER_NAME: $USER_NAME"
echo "WITNESS_NAMES : $WITNESS_NAMES"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $LOCAL_IP"
echo "P2P_PORT: $P2P_PORT"
echo "RPC_PORT: $RPC_PORT"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "PROJECT: $PROJECT"
echo "BRANCH: $BRANCH"
echo "BUILD_TYPE: $BUILD_TYPE"
echo "WITNESS_NODE: $WITNESS_NODE"
echo "CLI_WALLET: $CLI_WALLET"
echo "PUBLIC_BLOCKCHAIN_SERVER: $PUBLIC_BLOCKCHAIN_SERVER"
echo "TRUSTED_BLOCKCHAIN_DATA: $TRUSTED_BLOCKCHAIN_DATA"

##################################################################################################
# Update Ubuntu, configure a 2GiB swap file and install prerequisites for running BitShares      #
##################################################################################################
sudo apt-get -y update || exit 1;
sleep 5;
fallocate -l 2g /mnt/2GiB.swap
chmod 600 /mnt/2GiB.swap
mkswap /mnt/2GiB.swap
swapon /mnt/2GiB.swap
echo '/mnt/2GiB.swap swap swap defaults 0 0' | tee -a /etc/fstab
time apt-get -y install ntp g++ git make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev \
                        openssl libreadline-dev autoconf libtool libboost-all-dev

##################################################################################################
# Build BitShares from source                                                                    #
##################################################################################################
cd /usr/local/src
time git clone $GITHUB_REPOSITORY
cd $PROJECT
time git checkout $BRANCH
##################################################################################################
# TEST THE NEW FC BUILD HERE                                                                     #
##################################################################################################
sed -i 's%bitshares/bitshares-fc%aautushka/bitshares-fc%g' /usr/local/src/$PROJECT/.gitmodules
time git submodule update --remote libraries/fc
time git submodule update --init --recursive

sed -i 's%include_directories( vendor/equihash )%#include_directories( vendor/equihash )%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%src/crypto/equihash.cpp%#src/crypto/equihash.cpp%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%add_subdirectory( vendor/equihash )%#add_subdirectory( vendor/equihash )%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%${CMAKE_CURRENT_SOURCE_DIR}/vendor/equihash%#${CMAKE_CURRENT_SOURCE_DIR}/vendor/equihash%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%target_link_libraries( fc PUBLIC ${LINK_USR_LOCAL_LIB} equihash ${%target_link_libraries( fc PUBLIC ${LINK_USR_LOCAL_LIB} ${%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt

time cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE .
time make -j$NPROC

cp /usr/local/src/$PROJECT/programs/witness_node/witness_node /usr/bin/$WITNESS_NODE
cp /usr/local/src/$PROJECT/programs/cli_wallet/cli_wallet /usr/bin/$CLI_WALLET

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

##################################################################################################
# Start the service, allowing it to create the default application configuration file. Stop the  #
# service to allow modification of the config.ini file.                                          #
##################################################################################################
systemctl daemon-reload
systemctl enable $PROJECT
service $PROJECT start
sleep 5; # allow time to initializize application data.
service $PROJECT stop

##################################################################################################
# Connect the local CLI Wallet to a public blockchain server and open a local RPC listener.      #
# Connect to the local CLI Wallet to generate a new key pair for use locally by the block        #
# producer. Configure the config.ini file with the new key pair and block producer identity.     #
# This key pair will be used only as the signing key on this virtual machine.                    #
##################################################################################################
screen -dmS $CLI_WALLET /usr/bin/$CLI_WALLET -s $PUBLIC_BLOCKCHAIN_SERVER -H 127.0.0.1:8092
sleep 4; # allow time for CLI Wallet to connect to public blockchain server and open local RPC listener.
WITNESS_KEY_PAIR=$(curl -s --data '{"jsonrpc": "2.0", "method": "suggest_brain_key", "params": [], "id": 1}' http://127.0.0.1:8092 | \
    python3 -c "import sys, json; keys=json.load(sys.stdin); print('[\"'+keys['result']['pub_key']+'\",\"'+keys['result']['wif_priv_key']+'\"]')")
WITNESS_ID=$(curl -s --data '{"jsonrpc": "2.0", "method": "get_witness", "params": ["'$WITNESS_NAMES'"], "id": 1}' http://127.0.0.1:8092 | \
    python3 -c "import sys, json; print('\"'+json.load(sys.stdin)['result']['id']+'\"')")
screen -S $CLI_WALLET -p 0 -X quit

# Update the config.ini file with the new values.
sed -i 's/# witness-id =/witness-id = '$WITNESS_ID'/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/private-key =/private-key = '$WITNESS_KEY_PAIR' \nprivate-key =/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/# rpc-endpoint =/rpc-endpoint = '$LOCAL_IP':'$RPC_PORT'/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/level=debug/level=info/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini

##################################################################################################
# OPTIONAL: Download a recent blockchain snapshot from a trusted source. The blockchain is large #
# and will take many hours to validate using the trustless P2P network. A peer reviewed snapshot #
# is provided to facilatate rapid node deployment. Once the dowload is complete the service will #
# start and load the remaining blocks from the P2P network as normal.                            #
##################################################################################################
if (($BRANCH = "master")) ; then
mv /home/$USER_NAME/$PROJECT/witness_node/config.ini /home/$USER_NAME
rm -rfv /home/$USER_NAME/$PROJECT/witness_node/*
mv /home/$USER_NAME/config.ini /home/$USER_NAME/$PROJECT/witness_node
cd /home/$USER_NAME/$PROJECT/witness_node
time wget -qO- $TRUSTED_BLOCKCHAIN_DATA | tar xvz
fi

service $PROJECT start

##################################################################################################
# This VM is now configured as a block producing node. However, it will not sign blocks until    #
# the blochain receives a valid "update_witness" operation contianing the witness name and the   #
# pub_key written into the congif.ini file. The pub_key starts with the prefix 'BTS' (never 5).  #
##################################################################################################
