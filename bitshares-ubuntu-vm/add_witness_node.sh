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
BRANCH=master
BUILD_TYPE=Release
WITNESS_NODE=bts-witness
CLI_WALLET=bts-cli_wallet
TRUSTED_BLOCKCHAIN_DATA=https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/blockchain.tar.gz

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
echo "TRUSTED_BLOCKCHAIN_DATA: $TRUSTED_BLOCKCHAIN_DATA"

##################################################################################################
# Update Ubuntu, configure a swap file and install prerequisites for running BitShares                                  #
##################################################################################################
sudo apt-get -y update || exit 1;
sleep 5;
sed -i 's/ResourceDisk.Format=n/ResourceDisk.Format=y/g' /etc/waagent.conf
sed -i 's/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g' /etc/waagent.conf
sed -i 's/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=2048/g' /etc/waagent.conf
service walinuxagent restart
time apt-get -y install ntp g++ git make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev \
                        openssl libreadline-dev autoconf libtool libboost-all-dev

##################################################################################################
# Build BitShares from source                                                                    #
##################################################################################################
cd /usr/local/src
time git clone $GITHUB_REPOSITORY
cd $PROJECT
time git checkout $RELEASE
time git submodule update --init --recursive

sed -i 's/add_subdirectory( tests )/#add_subdirectory( tests )/g' /usr/local/src/$PROJECT/CMakeLists.txt
sed -i 's/add_subdirectory(tests)/#add_subdirectory(tests)/g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%auto history_plug = node->register_plugin%//auto history_plug = node->register_plugin%g' /usr/local/src/$PROJECT/programs/witness_node/main.cpp
sed -i 's%auto market_history_plug = node->register_plugin%//auto market_history_plug = node->register_plugin%g' /usr/local/src/$PROJECT/programs/witness_node/main.cpp
sed -i 's%include_directories( vendor/equihash )%#include_directories( vendor/equihash )%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%src/crypto/equihash.cpp%#src/crypto/equihash.cpp%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%add_subdirectory( vendor/equihash )%#add_subdirectory( vendor/equihash )%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%${CMAKE_CURRENT_SOURCE_DIR}/vendor/equihash%#${CMAKE_CURRENT_SOURCE_DIR}/vendor/equihash%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's%target_link_libraries( fc PUBLIC ${LINK_USR_LOCAL_LIB} equihash ${%target_link_libraries( fc PUBLIC ${LINK_USR_LOCAL_LIB} ${%g' /usr/local/src/$PROJECT/libraries/fc/CMakeLists.txt
sed -i 's/add_subdirectory( debug_node )/#add_subdirectory( debug_node )/g' /usr/local/src/$PROJECT/programs/CMakeLists.txt
sed -i 's/add_subdirectory( delayed_node )/#add_subdirectory( delayed_node )/g' /usr/local/src/$PROJECT/programs/CMakeLists.txt
sed -i 's/add_subdirectory( genesis_util )/#add_subdirectory( genesis_util )/g' /usr/local/src/$PROJECT/programs/CMakeLists.txt
sed -i 's/add_subdirectory( size_checker )/#add_subdirectory( size_checker )/g' /usr/local/src/$PROJECT/programs/CMakeLists.txt
sed -i 's/add_subdirectory( js_operation_serializer )/#add_subdirectory( js_operation_serializer )/g' /usr/local/src/$PROJECT/programs/CMakeLists.txt

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
# service, modify the config.ini file, then restart the service to apply the new RPC settings.   #
##################################################################################################
systemctl daemon-reload
systemctl enable $PROJECT
service $PROJECT start
sleep 5; # allow time to initializize application data
service $PROJECT stop
sed -i 's/# rpc-endpoint =/rpc-endpoint = '$LOCAL_IP':'$RPC_PORT'/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/level=debug/level=info/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
service $PROJECT start

##################################################################################################
# Connect to the CLI Wallet to generate a new keypair for use by the block producer as their     #
# unique signing keys. This key pair will only be used on this node for signing blocks.          #
##################################################################################################
screen -dmS $CLI_WALLET /usr/bin/$CLI_WALLET -s ws://$LOCAL_IP:$RPC_PORT -H 127.0.0.1:8092
sleep 2; # allow time to connect to RPC node
WITNESS_KEY_PAIR=$(curl -s --data '{"jsonrpc": "2.0", "method": "suggest_brain_key", "params": [], "id": 1}' http://127.0.0.1:8092 | \
    python3 -c "import sys, json; keys=json.load(sys.stdin); print('[\"'+keys['result']['pub_key']+'\",\"'+keys['result']['wif_priv_key']+'\"]')")
WITNESS_ID=$(curl -s --data '{"jsonrpc": "2.0", "method": "get_witness", "params": ["'$WITNESS_NAMES'"], "id": 1}' http://127.0.0.1:8092 | \
    python3 -c "import sys, json; print('\"'+json.load(sys.stdin)['result']['id']+'\"')")
screen -S $CLI_WALLET -p 0 -X quit

# Update the config.ini file with the new values.
sed -i 's/# witness-id =/witness-id = '$WITNESS_ID'/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/private-key =/private-key = '$WITNESS_KEY_PAIR' \nprivate-key =/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini

# Stop and restart the service to load the new settings.
service $PROJECT stop

##################################################################################################
# OPTIONAL: Download a recent blockchain snapshot from a trusted source. The blockchain is large #
# and will take many hours to validate using the trustless P2P network. A peer reviewed snapshot #
# is provided to facilatate rapid node deployment.                                               # 
##################################################################################################
time wget -qO- $TRUSTED_BLOCKCHAIN_DATA | tar xvz -C /home/$USER_NAME/$PROJECT/witness_node/blockchain

service $PROJECT start

##################################################################################################
# This VM is now configured as a block producing node. However, it will not sign blocks until    #
# the blochain receives a valid "update_witness" operation contianing the witness name and the   #
# pub_key written into the congif.ini file. The pub_key starts with the prefix 'BTS' (never 5).  #
##################################################################################################
