#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
NPROC=$(nproc)
ip=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`

echo "USER_NAME: $USER_NAME"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $ip"

##############################################################################################
# Update Ubuntu and install the prerequisites for running TESTNET BitShares witness node,    #
# command line (CLI) wallet and web wallet.                                                  #
##############################################################################################
time apt-get update
time apt-get install -y ntp apache2

##############################################################################################
# Install all necessary packages for building BitShares witness node and CLI.                #
##############################################################################################
time apt-get -y install ntp g++ git make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev \
                        openssl libreadline-dev autoconf libtool libboost-all-dev

##############################################################################################
# Build the TESTNET BitShares witness node and CLI wallet.          #
##############################################################################################
cd /usr/local
time git clone https://github.com/BitSharesEurope/graphene-testnet.git
cd graphene-testnet
time git submodule update --init --recursive
time cmake -DCMAKE_BUILD_TYPE=Release .
time make -j$NPROC

cp /usr/local/graphene-testnet/programs/witness_node/witness_node /usr/bin/testnet_witness_node
cp /usr/local/graphene-testnet/programs/cli_wallet/cli_wallet /usr/bin/testnet_cli_wallet

##################################################################################################
# Configure testnet service. Enable it to start on boot.                                       #
##################################################################################################
cat >/lib/systemd/system/testnet.service <<EOL
[Unit]
Description=Job that runs testnet daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/testnet/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/testnet/witness_node
ExecStart=/usr/bin/testnet_witness_node --rpc-endpoint=$IP:8090 -d /home/$USER_NAME/testnet/witness_node
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

##################################################################################################
# Install all necessary packages for building the BitShares web wallet.                          # 
##################################################################################################
time curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.30.2/install.sh | bash
nvm install v6
nvm use v6

##################################################################################################
# Build the TESTNET web wallet.                                                                  #
##################################################################################################
cd /usr/local
time git clone https://github.com/bitshares/bitshares-2-ui.git
cd bitshares-2-ui/web
npm install
npm start

##################################################################################################
# Configure TESTNET BitShares-UI to default to this VM (Replaces OpenLedger)                     #
##################################################################################################
#sed -i "s@connection: ""wss://bitshares.openledger.info/ws""@connection: ""ws://$FQDN:8090/ws""@" "/dl/src/stores/SettingsStore.js"
#sed -i "s@connection: [@connection: [\n                ""ws://$FQDN:8090/ws"",@" "/dl/src/stores/SettingsStore.js"

##################################################################################################
# Configure webserver for UI                                                                     #
##################################################################################################
#printf '<VirtualHost *:80>\n  DocumentRoot /usr/share/bitshares2-ui\n  ErrorLog ${APACHE_LOG_DIR}/error.log\n  CustomLog ${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>'>> /etc/apache2/sites-available/bitshares2-ui.conf
#a2dissite 000-default   # Disable the default Apache site
#a2ensite bitshares2-ui  # Enable Bitshares2-ui site
#service apache2 restart 

##################################################################################################
# Connect to the web wallet by pointing your web browser to:                                     #
# http://<VMname>.<region>.cloudapp.azure.com                                                    #
# The fully qualified domain name (FQDN) can be found within the Azure Portal under "DNS name"   #
# Learn more: http://docs.bitshares.eu                                                           #
##################################################################################################
