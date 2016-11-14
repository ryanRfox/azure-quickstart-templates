#!/bin/bash

# print commands and arguments as they are executed
set -x

#echo "starting ubuntu devbox install on pid $$"
date
ps axjf

NPROC=$(nproc)
INSTALL_METHOD=$1
USER_NAME=$2

#################################################################
# Update Ubuntu and install prerequisites for running BitShares #
#################################################################
time apt-get -y update
time apt-get install -y ntp

if [ $INSTALL_METHOD = 'From_PPA' ]; then
#################################################################
# Install BitShares from PPA                                    #
#################################################################
time add-apt-repository -y ppa:bitshares/bitshares
time apt-get -y update
time apt-get install -y bitshares2-cli

else    
#################################################################
# Build BitShares from source                                   #
#################################################################
time apt-get -y install g++ git cmake libbz2-dev libdb++-dev libdb-dev libssl-dev openssl libreadline-dev autoconf libtool libboost-all-dev

cd /usr/local
time git clone https://github.com/bitshares/bitshares-2.git
cd bitshares-2/
time git submodule update --init --recursive
time cmake -DCMAKE_BUILD_TYPE=Release .
time make -j$NPROC

cp /usr/local/bitshares-2/programs/witness_node/witness_node /usr/bin/bitshares_witness_node
cp /usr/local/bitshares-2/programs/cli_wallet/cli_wallet /usr/bin/bitshares_cli_wallet

fi

#################################################################
# Configure bitshares service                                   #
#################################################################
cat >/lib/systemd/system/bitshares.service <<EOL
[Unit]
Description=Job that runs bitshares daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/bitshares/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/bitshares/witness_node
ExecStart=/usr/bin/bitshares_witness_node --rpc-endpoint=127.0.0.1:8090 -d /home/$USER_NAME/bitshares/witness_node
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
service bitshares start

##################################################################################################
# Connect to host via SSH, then start cli wallet:                                                #
# $sudo /usr/bin/cli_wallet --wallet-file=/usr/local/bitshares-2/programs/cli-wallet/wallet.json #
# >set_password use_a_secure_password_but_check_your_shoulder_as_it_will_be_displayed_on_screen  #
# >ctrl-d [will save the wallet and exit the client]                                             #
# $nano /usr/local/bitshares-2/programs/cli-wallet/wallet.json                                   #
# Learn more: http://docs.bitshares.eu                                                           #
##################################################################################################
