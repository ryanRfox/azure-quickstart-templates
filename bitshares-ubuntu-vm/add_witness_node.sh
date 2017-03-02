#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
WITNESS_ID=$3
NPROC=$(nproc)
LOCAL_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8899
P2P_PORT=1776
PROJECT=graphene
SEED_NODE=graphene.eastus2.cloudapp.azure.com
WITNESS_NODE=graphene_witness_node
CLI_WALLET=graphene_cli_wallet

echo "USER_NAME: $USER_NAME"
echo "WITNESS_ID : $WITNESS_ID"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $LOCAL_IP"
echo "P2P_PORT: $P2P_PORT"
echo "RPC_PORT: $RPC_PORT"
echo "SEED_NODE: $SEED_NODE"
echo "PROJECT: $PROJECT"
echo "WITNESS_NODE: $WITNESS_NODE"
echo "CLI_WALLET: $CLI_WALLET"

sudo apt-get -y update || exit 1;
# To avoid intermittent issues with package DB staying locked when next apt-get runs
sleep 5;

##################################################################################################
# Clone the python-graphenelib project from the Xeroc source repository.                         #
##################################################################################################
apt -y install libffi-dev libssl-dev python-dev python3-pip
pip3 install pip --upgrade
cd /usr/local/src
time git clone https://github.com/xeroc/python-graphenelib.git
cd python-graphenelib
git checkout 0.4.8
pip3 install autobahn pycrypto graphenelib 
python3 setup.py install --user

##################################################################################################
# Download the pre-compiled witness_node and cli_wallet provided by the trusted source for this  #
# the GRAPHENE TEST.                                                                             #
##################################################################################################
cd  /usr/bin/
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/$WITNESS_NODE
chmod +x $WITNESS_NODE

time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/$CLI_WALLET
chmod +x $CLI_WALLET

mkdir /home/$USER_NAME/key_gen
cd /home/$USER_NAME/key_gen
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/testnet_cli_wallet
chmod +x testnet_cli_wallet

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
ExecStart=/usr/bin/$WITNESS_NODE --data-dir /home/$USER_NAME/$PROJECT/witness_node \
                                 --seed-node $SEED_NODE:$P2P_PORT
TimeoutSec=300
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable $PROJECT
service $PROJECT start
service $PROJECT stop

##################################################################################################
# Create a python script to modify the config.ini file with our custom values.                   #
##################################################################################################
cat >/home/$USER_NAME/key_gen/modify_config.py <<EOL
# Call this script with: modify_config.py <config_file> <witness_object_id>
import sys
import time
import json
import fileinput
import subprocess
from grapheneapi.grapheneclient import GrapheneClient
from grapheneapi.graphenewsprotocol import GrapheneWebsocketProtocol

class Config(GrapheneWebsocketProtocol):
    wallet_host           = "localhost"
    wallet_port           = 8092
    wallet_user           = ""
    wallet_password       = ""

    witness_url           = "wss://node.testnet.bitshares.eu/"
    witness_user          = ""
    witness_password      = ""

configSourcePath      = sys.argv[1]
withnessObjectId      = sys.argv[2]

def startCliWallet(screen_name,cli_wallet_path,witness_url,wallet_host,wallet_json_file):
    print("Starting CLI_Wallet...")
    subprocess.call(["screen","-dmS",screen_name,cli_wallet_path,"-s",witness_url,"-H",wallet_host,"-w",wallet_json_file])

def stopCliWallet(screen_name):
    print("Closing CLI_Wallet...")
    subprocess.call(["screen","-S",screen_name,"-p","0","-X","quit"])

def modifyConfig(sourceFile, objId):
    myBrainKeyJson     = graphene.rpc.suggest_brain_key()
    witnessIdStr  = "witness-id  = \"1.6."+str(objId)+"\"""
    privateKeyStr = "private-key = [\""+myBrainKeyJson["pub_key"]+"\",\""+myBrainKeyJson["wif_priv_key"]+"\"]"
    with fileinput.FileInput(sourceFile, inplace=True, backup='.bak') as file:
        for line in file:
            print(line.replace('# witness-id =', witnessIdStr), end='')
    with fileinput.FileInput(configSourcePath, inplace=True, backup='.bak') as file:
        for line in file:
            print(line.replace('# Tuple of [PublicKey, WIF private key] (may specify multiple times)', '# Tuple of [PublicKey, WIF private key] (may specify multiple times)\n'+privateKeyStr), end='')

if __name__ == '__main__':
    startCliWallet("testnet_cli_wallet","/home/$USER_NAME/key_gen/testnet_cli_wallet","wss://node.testnet.bitshares.eu/","127.0.0.1:8092","/home/$USER_NAME/key_gen/wallet.json")
    time.sleep(2)
    graphene = GrapheneClient(Config)
    modifyConfig(configSourcePath,withnessObjectId)
    stopCliWallet("testnet_cli_wallet")
    print("Done.")

EOL

python3 modify_config.py /home/$USER_NAME/graphene/witness_node/config.ini $WITNESS_ID
sed -i 's/TEST/GPH/g' /home/$USER_NAME/graphene/witness_node/config.ini

service $PROJECT start
