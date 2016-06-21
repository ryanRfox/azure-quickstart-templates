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
# Create steem service, then start (blank state)                #
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

systemctl daemon-reload
service steem start
sleep 10

#################################################################
# Create cli_wallet service, then start                         #
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
sleep 10

#################################################################
# Generate the private key for mining on this virtual machine   #
# using "suggest_brain_key" function from the local cli_wallet. #
# Write the file to /home/$USER_NAME/brain_key.json             #
#################################################################
curl -o /home/$USER_NAME/brain_key.json --data '{"jsonrpc": "2.0", "method": "call", "params": [0,"suggest_brain_key",[]], "id": 2}' http://127.0.0.1:8092/rpc
WIF_PRIV_KEY=$( cat /home/$USER_NAME/brain_key.json | jq '.result.wif_priv_key' )

service cli_wallet stop
service steem stop

#################################################################
# Remove cli_wallet service                                     #
#################################################################
rm /lib/systemd/system/cli_wallet.service

#################################################################
# (OPTIONAL) Send the private keys by email iff the user made   #
# the request in the Azure template.                            #
#################################################################
# TODO: install mail relay
# TODO: encrypt brain_key.json using a passed value
# TODO: send email containing encrypted brain_key.json with instructions. Remind unencrypted file remains on VM.
# TODO: uninstall mail relay

#################################################################
# Re-Configure steem service with private key, start mining     #
#################################################################
cat >/lib/systemd/system/steem.service <<EOL
[Unit]
Description=Job that runs steem daemon

[Service]
Environment=statedir=/home/$USER_NAME/steem/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/steem/witness_node
ExecStart=/usr/bin/steemd --rpc-endpoint=127.0.0.1:8090 \
--witness='"$DESIRED_NAME"' \
--miner='["$DESIRED_NAME",$WIF_PRIV_KEY]' \
--mining-threads=$NPROC \
-s 212.117.213.186:2016           # liondani
-s 185.82.203.92:2001             # riverhead
-s 104.236.82.250:2001            # svk
-s seed.steemnodes.com:2001       # wackou
-s steemseed.dele-puppy.com:2001  # puppies
-s steem-seed1.abit-more.com:2001 # abit
-s 213.167.243.223:2001           # bhuz
-s 52.4.250.181:39705             # lafona
-s 46.252.27.1:1337               # jabbasteem
-d /home/$USER_NAME/steem/witness_node

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
service steem start

#################################################################
# Create a script to launch the cli_wallet using a wallet file  #
# stored at /home/$USER_NAME/steem/cli_wallet/wallet.json       #
#################################################################
cat >/home/$USER_NAME/launch_steem_wallet.sh <<EOL
/usr/bin/cli_wallet -w /home/$USER_NAME/steem/cli_wallet/wallet.json
EOL
chmod u+x /home/$USER_NAME/launch_steem_wallet.sh

#################################################################
# Steemd is now actively mining the desired name using the      #
# private key generated on this virtual machine. Please logon   #
# to the VM and locate: /home/$USER_NAME/brain_key.json         #
# Recommendation: remove this file from the VM and retain the   #
# information in a secure location. The file contains your      #
# brain key text, private key & public key.                     #
#                                                               #
#################################################################
