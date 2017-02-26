#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
ACCOUNT_NAMES=$3
NPROC=$(nproc)
LOCAL_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8899
P2P_PORT=1776
PROJECT=graphene
GITHUB_REPOSITORY=https://github.com/cryptonomex/graphene.git
WITNESS_NODE=graphene_witness_node
CLI_WALLET=graphene_cli_wallet

echo "USER_NAME: $USER_NAME"
echo "ACCOUNT_NAMES : $ACCOUNT_NAMES"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $LOCAL_IP"
echo "P2P_PORT: $P2P_PORT"
echo "RPC_PORT: $RPC_PORT"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "PROJECT: $PROJECT"
echo "WITNESS_NODE: $WITNESS_NODE"
echo "CLI_WALLET: $CLI_WALLET"

echo "Begin Update..."
sudo apt-get -y update || exit 1;
# To avoid intermittent issues with package DB staying locked when next apt-get runs
sleep 5;

#echo "Begin Upgrade..."
#apt-get upgrade -y
#echo "Upgrade complete."

##############################################################################################
# Clone the Graphene project from the Cryptonomex source repository. Initialize the project. #
# Eliminate the test folder to speed up the build time by about 20%. Modify the config.hpp   #
# file to set the address prefix to our deisired value.                                      # 
##############################################################################################
echo "Clone Graphene project"
cd /usr/local/src
time git clone $GITHUB_REPOSITORY
cd $PROJECT
time git submodule update --init --recursive
sed -i 's/add_subdirectory( tests )/#add_subdirectory( tests )/g' /usr/local/src/graphene/CMakeLists.txt
# sed -i 's/define GRAPHENE_ADDRESS_PREFIX "GPH"/define GRAPHENE_ADDRESS_PREFIX "+$ADDRESS_PREFIX+"/g' /usr/local/src/graphene/libraries/chain/include/graphene/chain/config.hpp

##################################################################################################
# Clone the python-graphenelib project from the Xeroc source repository.                         #
##################################################################################################
apt -y install libffi-dev libssl-dev python-dev python3-pip
pip3 install pip --upgrade
cd /usr/local/src
time git clone https://github.com/xeroc/python-graphenelib.git
cd python-graphenelib
pip3 install autobahn pycrypto graphenelib # python-requests
python3 setup.py install --user

##################################################################################################
# Download a TESTNET pre-compiled cli_wallet to generate new key pairs. Make the file executable.#
##################################################################################################
mkdir /home/$USER_NAME/key_gen/
cd /home/$USER_NAME/key_gen/
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/testnet_cli_wallet
chmod +x testnet_cli_wallet

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

def stopCliWallet(screen_name):
    print("Closing CLI_Wallet...")
    subprocess.call(["screen","-S",screen_name,"-p","0","-X","quit"])

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
    print("Starting genesis file modifications...")
    i = 0
    account_data = {}
    account_data['Accounts'] = []
    with open(genesisSourcePath, 'r+') as file:
        json_data = json.load(file, object_pairs_hook=OrderedDict)
        dt = (datetime.datetime.now() + datetime.timedelta(seconds=300)).replace(second=0)
        print("    Updating timestamp...")
        json_data['initial_timestamp'] = dt.replace(microsecond=0).isoformat()
        for account in newAccounts:
            print("    Adding account and keys for",account,"...")
            brainKeyJson     = graphene.rpc.suggest_brain_key()
            wifPrivKey       = brainKeyJson["wif_priv_key"]
            pubKey           = brainKeyJson["pub_key"]
            json_data['initial_witness_candidates'][i]['owner_name'] = account
            json_data['initial_witness_candidates'][i]['block_signing_key'] = pubKey
            json_data['initial_accounts'][i]['name'] = account
            json_data['initial_accounts'][i]['owner_key'] = pubKey
            json_data['initial_accounts'][i]['active_key'] = pubKey
            json_data['initial_committee_candidates'][i]['owner_name'] = account
            account_data['Accounts'].append({
                'name': account,
                'keys': brainKeyJson 
            })
            i = i + 1
        file.seek(0)
        file.write(json.dumps(json_data, indent=4))
        file.truncate()
        with open('account_keys.json', 'w') as outfile:  
            json.dump(account_data, outfile, indent=4)
    print("All genesis file modifications complete.")


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
    stopCliWallet("testnet_cli_wallet")
    print("Done.")
EOL

##############################################################################################
# Get a genesis file template, then modify it with your desired values.                      #
##############################################################################################
cd /home/$USER_NAME/key_gen
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/my-genesis.json
python3 modify_genesis.py $ACCOUNT_NAMES /home/$USER_NAME/key_gen/my-genesis.json
sed -i 's/TEST/GPH/g' /home/$USER_NAME/key_gen/account_keys.json
sed -i 's/TEST/GPH/g' /home/$USER_NAME/key_gen/my-genesis.json
cp /home/$USER_NAME/key_gen/my-genesis.json /usr/local/src/$PROJECT/genesis.json

##############################################################################################
# Install all necessary packages for building PRIVATE GRAPHENE witness node and CLI.         #
##############################################################################################
time apt -y install ntp g++ make cmake libbz2-dev libdb++-dev libdb-dev libssl-dev openssl \
                    libreadline-dev autoconf libtool libboost-all-dev

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
# Create a python script to modify the config.ini file with our custom values.                   #
##################################################################################################
cat >/home/$USER_NAME/key_gen/modify_config.py <<EOL
# Call this script with: modify_config.py <config_file> <json_file_containing_accounts_with_brainkeys>
from collections import OrderedDict
import sys
import json
import fileinput

configSourcePath      = sys.argv[1]
accountsJsonPath      = sys.argv[2]

def modifyConfig(configSourcePath, accountsJsonPath):
    i = 0
    witnessIdStr  = ""
    privateKeyStr = ""
    with open(accountsJsonPath, 'r+') as keyfile:
        json_data = json.load(keyfile, object_pairs_hook=OrderedDict)
        Accounts = json_data['Accounts']
        for account in Accounts:
            i = i + 1
            witnessIdStr = witnessIdStr + "witness-id  = \"1.6."+str(i)+"\"\n"
        while i < 12:
            witnessIdStr = witnessIdStr + "witness-id  = \"1.6."+str(i)+"\"\n"
            i = i + 1
        i = 0
        for account in Accounts:
            privateKeyStr = privateKeyStr + "private-key = [\""+Accounts[i]['keys']["pub_key"]+"\",\""+Accounts[i]['keys']["wif_priv_key"]+"\"]\n"
            i = i + 1
    keyfile.close()

    with fileinput.FileInput(configSourcePath, inplace=True, backup='.bak') as file:
        for line in file:
            print(line.replace('# witness-id =', witnessIdStr), end='')
    with fileinput.FileInput(configSourcePath, inplace=True, backup='.bak') as file:
        for line in file:
            print(line.replace('# Tuple of [PublicKey, WIF private key] (may specify multiple times)', '# Tuple of [PublicKey, WIF private key] (may specify multiple times)\n'+privateKeyStr), end='')

if __name__ == '__main__':
    modifyConfig(configSourcePath,accountsJsonPath)

EOL

##################################################################################################
# Start the graphene service to allow it to create the default configuration file. Stop the      #
# service, modify the config.ini file, then restart the service with the new settings applied.   #
##################################################################################################
service $PROJECT start
service $PROJECT stop
cd /home/$USER_NAME/key_gen/
sed -i 's/# p2p-endpoint =/p2p-endpoint = '$LOCAL_IP':'$P2P_PORT'/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/# rpc-endpoint =/rpc-endpoint = '$LOCAL_IP':'$RPC_PORT'/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/enable-stale-production = false/enable-stale-production = true/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
sed -i 's/level=debug/level=info/g' /home/$USER_NAME/$PROJECT/witness_node/config.ini
python3 modify_config.py /home/$USER_NAME/graphene/witness_node/config.ini /home/$USER_NAME/key_gen/account_keys.json
service $PROJECT start

##################################################################################################
# Install all necessary packages for building the PRIVATE GRAPHENE web wallet.                   # 
##################################################################################################
time apt install -y apache2 npm
cd /usr/local/src
time curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.30.2/install.sh | bash
source ~/.profile
nvm install v6

##################################################################################################
# Clone and install the PRIVATE GRAPHENE web wallet.                                             #
##################################################################################################
cd /usr/local/src
time git clone https://github.com/Cryptonomex/graphene-ui.git
cd graphene-ui/web
nvm use v6
npm install

##################################################################################################
# Configure PRIVATE GRAPHENE-UI to default to this VM (Replaces OpenLedger)                      #
##################################################################################################
sed -i 's%let apiServer = \[%let apiServer = [\n            {url: "ws://'$FQDN':'$RPC_PORT'/ws", location: "Azure Cloud"},%g' /usr/local/src/graphene-ui/web/app/stores/SettingsStore.js
sed -i 's%apiServer: "wss://bitshares.openledger.info/ws"%apiServer: "ws://'$FQDN':'$RPC_PORT'/ws"%g' /usr/local/src/graphene-ui/web/app/stores/SettingsStore.js

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
