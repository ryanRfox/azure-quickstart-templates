#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
NPROC=$(nproc)
IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8090 

echo "USER_NAME: $USER_NAME"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $IP"
echo "RPC_PORT: $RPC_PORT"

##############################################################################################
# Update Ubuntu and install the prerequisites for running PRIVATE GRAPHENE witness node,     #
# command line (CLI) wallet and web wallet.                                                  #
##############################################################################################
time apt-get update
time apt-get install -y ntp apache2

##############################################################################################
# Install all necessary packages for building PRIVATE GRAPHENE witness node and CLI.         #
##############################################################################################
time apt-get -y install ntp g++ git make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev \
                        openssl libreadline-dev autoconf libtool libboost-all-dev

##############################################################################################
# Clone the Graphene project from the Cryptonomex source repository.                         #
##############################################################################################
cd /usr/local
time git clone https://github.com/Cryptonomex/graphene.git
cd graphene
time git submodule update --init --recursive

##############################################################################################
# Download genesis file template, then modify it with desired values                         #
##############################################################################################
curl -o genesis.json
# "initial_timestamp": "2017-01-31T04:48:00",
# "block_interval": 5,

# suggest_brain_key per account

#  "initial_accounts": [{
#      "name": "init0",
#      "owner_key": "GPH6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV",
#      "active_key": "GPH6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV",
#      "is_lifetime_member": true
#    },

#  "initial_witness_candidates": [{
#      "owner_name": "init0",
#      "block_signing_key": "GPH6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV"
#    }
	
#cat >> config.ini <<EOL
#EOL

##############################################################################################
# Build the PRIVATE GRAPHENE witness node and CLI wallet.                                    #
##############################################################################################
time cmake -DCMAKE_BUILD_TYPE=Debug \
           -DGRAPHENE_EGENESIS_JSON="/usr/local/graphene/programs/witness_node/genesis.json" .
time make -j$NPROC

cp /usr/local/graphene/programs/witness_node/witness_node /usr/bin/graphene_witness_node
cp /usr/local/graphene/programs/cli_wallet/cli_wallet /usr/bin/graphene_cli_wallet

##################################################################################################
# Configure graphene service. Enable it to start on boot.                                        #
##################################################################################################
cat >/lib/systemd/system/graphene.service <<EOL
[Unit]
Description=Job that runs graphene daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/graphene/witness_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/graphene/witness_node
ExecStart=/usr/bin/graphene_witness_node --rpc-endpoint=$IP:$RPC_PORT \
                                         -d /home/$USER_NAME/graphene/witness_node
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable graphene

##################################################################################################
# Start the graphene service to allow it to create the default configuration file. Stop the      #
# service, modify the config.ini file, then restart the service with the new settings applied.   #
##################################################################################################
service graphene start
wait 10
sed -i 's/level=debug/level=info/g' /home/$USER_NAME/graphene/witness_node/config.ini
service graphene stop
wait 10
service graphene start

##################################################################################################
# Install all necessary packages for building the PRIVATE GRAPHENE web wallet.                   # 
##################################################################################################
time curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.30.2/install.sh | bash
nvm install v6
nvm use v6

##################################################################################################
# Build the PRIVATE GRAPHENE web wallet.                                                         #
##################################################################################################
cd /usr/local
time git clone https://github.com/Cryptonomex/graphene-ui.git
cd graphene-ui/web
npm install
npm start

##################################################################################################
# Configure PRIVATE GRAPHENE-UI to default to this VM (Replaces OpenLedger)                      #
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
