#!/bin/bash
set -x

date
ps axjf

##################################################################################################
# Set the variables.                                                                             #
##################################################################################################
NPROC=$(nproc)
USER_NAME=$1

##################################################################################################
# Update Ubuntu and install prerequisites for running BitShares                                  #
##################################################################################################
time apt-get -y update
time apt-get -y install ntp g++ git make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev openssl libreadline-dev autoconf libtool libboost-all-dev

##################################################################################################
# Build BitShares from source                                                                    #
##################################################################################################
cd /usr/local
time git clone https://github.com/BitSharesEurope/graphene-testnet.git
cd graphene-testnet
time git submodule update --init --recursive
time cmake -DCMAKE_BUILD_TYPE=Release .
time make -j$NPROC

cp /usr/local/graphene-testnet/programs/witness_node/witness_node /usr/bin/testnet_witness_node
cp /usr/local/graphene-testnet/programs/cli_wallet/cli_wallet /usr/bin/testnet_cli_wallet

##################################################################################################
# Configure bitshares service. Enable it to start on boot.                                       #
##################################################################################################
cat >/lib/systemd/system/testnet.service <<EOL
[Unit]
Description=Job that runs testnet daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/testnet/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/testnet/witness_node
ExecStart=/usr/bin/testnet_witness_node --rpc-endpoint=127.0.0.1:8090 -d /home/$USER_NAME/testnet/witness_node
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable testnet

##################################################################################################
# Start the testnet service to allow it to create the default configuration file. Stop the       #
# service, modify the config.ini file, then restart the service with the new settings applied.   #
##################################################################################################
service testnet start
wait 10
sed -i 's/level=debug/level=info/g' /home/$USER_NAME/testnet/witness_node/config.ini
service testnet stop
wait 10
service testnet start

########################################################################################################
# Connect to host via SSH, then start cli wallet:                                                      #
# $sudo /usr/bin/testnet_cli_wallet --wallet-file=/usr/local/testnet/programs/cli-wallet/wallet.json   #
# >set_password use_a_secure_password_but_check_your_shoulder_as_it_will_be_displayed_on_screen        #
# >ctrl-d [will save the wallet and exit the client]                                                   #
# $nano /usr/local/testnet/programs/cli-wallet/wallet.json                                             #
# Learn more: http://docs.bitshares.eu                                                                 #
########################################################################################################
