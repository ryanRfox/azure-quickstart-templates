#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
#FQDN=$2
ACCOUNT_NAMES=$2
NPROC=$(nproc)
RPC_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8899
PROJECT=graphene
GITHUB_REPOSITORY=https://github.com/cryptonomex/graphene.git
WITNESS_NODE=graphene_witness_node
CLI_WALLET=graphene_cli_wallet

echo "USER_NAME: $USER_NAME"
echo "ACCOUNT_NAMES : $ACCOUNT_NAMES"
#echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $RPC_IP"
echo "RPC_PORT: $RPC_PORT"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "PROJECT: $PROJECT"
echo "WITNESS_NODE: $WITNESS_NODE"
echo "CLI_WALLET: $CLI_WALLET"

##############################################################################################
# Clone the Graphene project from the Cryptonomex source repository.                         #
##############################################################################################
cd /usr/local/src
time git clone $GITHUB_REPOSITORY
cd $PROJECT
time git submodule update --init --recursive

##################################################################################################
# Clone the python-graphenelib project from the Xeroc source repository.                         #
##################################################################################################
apt -y install libffi-dev libssl-dev python-dev python3-pip
pip3 install pip --upgrade
cd /usr/local/src
time git clone https://github.com/xeroc/python-graphenelib.git
cd python-graphenelib
#pip3 install autobahn pycrypto python-requests # graphenelib 
python3 setup.py install --user

##################################################################################################
# Download a TESTNET pre-compiled cli_wallet to generate new key pairs. Download a default       #
# genesis file to modify.                                                                        #
##################################################################################################
mkdir /home/$USER_NAME/key_gen/
cd /home/$USER_NAME/key_gen/
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/testnet_cli_wallet
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/my-genesis.json

##################################################################################################
# Create a python script to modify a default genesis file with our custom values.                #
##################################################################################################
cat >/home/$USER_NAME/key_gen/modify_genesis.py <<EOL
# Call this script with: modify_genesis.py <comma_delimited_account_name_list> <source_file_path> 

from grapheneapi.grapheneclient import GrapheneClient
from grapheneapi.graphenewsprotocol import GrapheneWebsocketProtocol
from collections import OrderedDict
import sys
import time
import datetime
import subprocess
import json

newAccounts            = sys.argv[1].split(",")
genesisSourcePath      = sys.argv[2]

class Config(GrapheneWebsocketProtocol):
    wallet_host           = "localhost"
    wallet_port           = 8092
    wallet_user           = ""
    wallet_password       = ""

    witness_url           = "wss://node.testnet.bitshares.eu/"
    witness_user          = ""
    witness_password      = ""

def startCliWallet(screen_name,cli_wallet_path,witness_url,wallet_host,wallet_json_file):
    print("Starting CLI_Wallet...")
    subprocess.call(["screen","-dmS",screen_name,cli_wallet_path,"-s",witness_url,"-H",wallet_host,"-w",wallet_json_file])

def createAccountWithBrainKey(newAccount):
    myBrainKeyJson     = graphene.rpc.suggest_brain_key()
    myBrainKey         = myBrainKeyJson["brain_priv_key"]
    myNewAccount       = newAccount
    myRegistrarAccount = "nathan"
    myReferreAccount   = "nathan"
    myBroadcast        = True
    tx = graphene.rpc.create_account_with_brain_key(myBrainKey,myNewAccount,myRegistrarAccount,myReferreAccount,myBroadcast)
    print(tx)

def modifyGenesisFile():
    i = 0
    with open(genesisSourcePath, 'r+') as file:
        json_data = json.load(file, object_pairs_hook=OrderedDict)
        json_data['initial_timestamp'] = str(datetime.datetime.now() + datetime.timedelta(seconds=300))
        for account in newAccounts:
            print(account)
            brainKeyJson     = graphene.rpc.suggest_brain_key()
            print(brainKeyJson)
            wifPrivKey       = brainKeyJson["wif_priv_key"]
            pubKey           = brainKeyJson["pub_key"].replace("TEST", "GPH")
            # TODO: store the priv_key for later use within the wallet(s)
            json_data['initial_witness_candidates'][i]['owner_name'] = account
            json_data['initial_witness_candidates'][i]['block_signing_key'] = pubKey
            json_data['initial_accounts'][i]['name'] = account
            json_data['initial_accounts'][i]['owner_key'] = pubKey
            json_data['initial_accounts'][i]['active_key'] = pubKey
            json_data['initial_committee_candidates'][i]['owner_name'] = account
            i = i + 1
        file.seek(0)
        file.write(json.dumps(json_data, indent=4))
        file.truncate()

def importAccountKeys(accounts, privateKeys):
    i = 0
    for account in accounts:
        print(privateKeys[i])
        i = i + 1
#        graphene.rpc.import_key(privateKeys[account])

if __name__ == '__main__':
    startCliWallet("testnet_cli_wallet","/home/$USER_NAME/key_gen/testnet_cli_wallet","wss://node.testnet.bitshares.eu/","127.0.0.1:8092","/home/$USER_NAME/key_gen/wallet.json")
    time.sleep(5)
    graphene = GrapheneClient(Config)
    print(graphene.rpc.about())
    modifyGenesisFile()
EOL

##############################################################################################
# Get a genesis file template, then modify it with your desired values.                      #
##############################################################################################
cd /home/$USER_NAME/key_gen
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/my-genesis.json
python3 modify_genesis.py $ACCOUNT_NAMES /home/$USER_NAME/key_gen/my-genesis.json
cp /home/$USER_NAME/key_gen/my-genesis.json /usr/local/src/$PROJECT/genesis.json

##############################################################################################
# Install all necessary packages for building PRIVATE GRAPHENE witness node and CLI.         #
##############################################################################################
time apt-get -y install ntp g++ git make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev \
                        openssl libreadline-dev autoconf libtool libboost-all-dev

##############################################################################################
# Build the PRIVATE GRAPHENE witness node and CLI wallet.                                    #
##############################################################################################
cd /usr/local/src/$PROJECT/
make clean
find . -name "CMakeCache.txt" | xargs rm -f
find . -name "CMakeFiles" | xargs rm -Rf
time cmake -DCMAKE_BUILD_TYPE=Debug \
           -DGRAPHENE_EGENESIS_JSON="/usr/local/src/$PROJECT/genesis.json" .
time make -j$NPROC

cp /usr/local/src/$PROJECT/programs/witness_node/witness_node /usr/bin/$WITNESS_NODE
cp /usr/local/src/$PROJECT/programs/cli_wallet/cli_wallet /usr/bin/$CLI_WALLET

##################################################################################################
# Configure graphene service. Enable it to start on boot.                                        #
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

##################################################################################################
# Start the graphene service to allow it to create the default configuration file. Stop the      #
# service, modify the config.ini file, then restart the service with the new settings applied.   #
##################################################################################################
service $PROJECT start
wait 10
sed -i 's/level=debug/level=info/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/# rpc-endpoint =/rpc-endpoint = '$RPC_IP':'$RPC_PORT'/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/enable-stale-production = false/enable-stale-production = true/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
# replace witness-id = "1.6.0"
# [...]
# replace witness-id = "1.6.10"
# replace private-key = 
service $PROJECT stop
wait 10
service $PROJECT start

##################################################################################################
# Install all necessary packages for building the PRIVATE GRAPHENE web wallet.                   # 
##################################################################################################
time apt install -y apache2
time curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.30.2/install.sh | bash
nvm install v6
nvm use v6

##################################################################################################
# Clone and install the PRIVATE GRAPHENE web wallet.                                             #
##################################################################################################
cd /usr/local/src
time git clone https://github.com/Cryptonomex/graphene-ui.git
cd graphene-ui/web
npm install

##################################################################################################
# Configure PRIVATE GRAPHENE-UI to default to this VM (Replaces OpenLedger)                      #
##################################################################################################
sed -i 's%let apiServer = \[%let apiServer = [\n            {url: "ws://'$FQDN':'$RPC_PORT'/ws", location: "Azure Cloud"},%g' /usr/local/graphene-ui/web/app/stores/SettingsStore.js
sed -i 's%apiServer: "wss://bitshares.openledger.info/ws"%apiServer: "ws://'$FQDN':'$RPC_PORT'/ws"%g' /usr/local/graphene-ui/web/app/stores/SettingsStore.js

##################################################################################################
# Build the PRIVATE GRAPHENE web wallet and move it to the web root folder.                      #
##################################################################################################
time npm run build 
mv dist/ /var/www/graphene-ui

##################################################################################################
# Configure the web server to host the GRAPHENE-UI content                                       #
##################################################################################################
printf '<VirtualHost *:80>\n  DocumentRoot /var/www/graphene-ui\n  ErrorLog ${APACHE_LOG_DIR}/error.log\n  CustomLog ${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>'>> /etc/apache2/sites-available/graphene-ui.conf
a2dissite 000-default   # Disable the default Apache site
a2ensite graphene-ui  # Enable GRAPHENE-UI site
service apache2 restart 

##################################################################################################
# Connect to the web wallet by pointing your web browser to:                                     #
# http://<VMname>.<region>.cloudapp.azure.com                                                    #
# The fully qualified domain name (FQDN) can be found within the Azure Portal under "DNS name"   #
# Learn more: http://docs.bitshares.eu                                                           #
##################################################################################################
