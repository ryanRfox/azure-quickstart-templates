#!/bin/bash

# print commands and arguments as they are executed
set -x

#echo "starting ubuntu devbox install on pid $$"
date
ps axjf

NPROC=$(nproc)
INSTALL_METHOD=$1
USER_NAME=$2
DESIRED_NAME=$3

cat >/home/vars.txt <<EOL
$NPROC
$INSTALL_METHOD
$USER_NAME
$DESIRED_NAME
EOL

#################################################################
# Update Ubuntu and install prerequisites for launching Steemd  #
#################################################################
time apt-get -y update
time apt-get -y install ntp git cmake g++ libbz2-dev libdb++-dev
time apt-get -y install libdb-dev libssl-dev openssl libreadline-dev autoconf
time apt-get -y install libtool libboost-all-dev ncurses-dev doxygen
wget http://stedolan.github.io/jq/download/linux64/jq
chmod +x ./jq
mv jq /usr/bin

#################################################################
# Build Steemd and CLI Wallet from source                       #
#################################################################
cd /usr/local
time git clone https://github.com/steemit/steem
cd steem/
time git submodule update --init --recursive
cmake -DENABLE_CONTENT_PATCHING=OFF .
time make -j$NPROC

cp /usr/local/steem/programs/steemd/steemd /usr/bin/steemd
cp /usr/local/steem/programs/cli_wallet/cli_wallet /usr/bin/cli_wallet

#################################################################
# Configure steem service, then start (blank state)             #
#################################################################
cat >/lib/systemd/system/steem.service <<EOL
[Unit]
Description=Job that runs steem daemon

[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/steem/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/steem/witness_node
ExecStart=/usr/bin/steemd --rpc-endpoint=127.0.0.1:8090 \
-d /home/$USER_NAME/steem/witness_node

[Install]
WantedBy=multi-user.target
EOL

cp /lib/systemd/system/steem.service /home/$USER_NAME/steem.service
systemctl daemon-reload
service steem start

#################################################################
# Configure cli_wallet service, then start                      #
#################################################################
cat >/lib/systemd/system/cli_wallet.service <<EOL
[Unit]
Description=Job that runs cli_wallet daemon

[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/steem/cli_wallet
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/steem/cli_wallet
ExecStart=/usr/bin/cli_wallet --rpc-endpoint=127.0.0.1:8092 \
--rpc-http-allowip=127.0.0.1 \
-w /home/$USER_NAME/steem/cli_wallet/wallet.json \
-d

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
service cli_wallet start

#################################################################
# Generate the private key for mining on this virtual machine   #
#################################################################
curl -o /home/$USER_NAME/brain_key.json --data '{"jsonrpc": "2.0", "method": "call", "params": [0,"suggest_brain_key",[]], "id": 2}' http://127.0.0.1:8092/rpc
WIF_PRIV_KEY=$( cat /home/$USER_NAME/brain_key.json | jq '.result.wif_priv_key' )

#service cli_wallet stop
#service steem stop

#################################################################
# Re-Configure steem service with private settings, then start  #
#################################################################
cat >/lib/systemd/system/steem.service <<EOL
[Unit]
Description=Job that runs steem daemon

[Service]
Environment=statedir=/home/$USER_NAME/steem/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/steem/witness_node
ExecStart=/usr/bin/steemd --rpc-endpoint=127.0.0.1:8090 \
--witness='"$DESIRED_NAME"' \
--private-key=$WIF_PRIV_KEY \
--miner='["$DESIRED_NAME",$WIF_PRIV_KEY]' \
--mining-threads=$NPROC \
-s steem.kushed.com:2001 \
-s steemd.pharesim.me:2001 \
-s seed.steemnodes.com:2001 \
-s steemseed.dele-puppy.com:2001 \
-s seed.steemwitness.com:2001  \
-s seed.steemed.net:2001 \
-d /home/$USER_NAME/steem/witness_node

[Install]
WantedBy=multi-user.target
EOL

#systemctl daemon-reload
#service steem start

#################################################################
# Steemd is now actively mining the desired name using the      #
# private key generated on this virtual machine. Please logon   #
# to the VM to locate the file: ~/brain_key.txt                 #
# Please retain the information within this file for future use #
# as it contains your brain key text, private key & public key. #
#################################################################

