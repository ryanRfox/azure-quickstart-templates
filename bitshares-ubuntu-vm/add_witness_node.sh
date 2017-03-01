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
SEED_NODE=baas-01.eastus2.cloudapp.azure.com
WITNESS_NODE=graphene_witness_node
CLI_WALLET=graphene_cli_wallet

echo "USER_NAME: $USER_NAME"
echo "ACCOUNT_NAMES : $ACCOUNT_NAMES"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $LOCAL_IP"
echo "P2P_PORT: $P2P_PORT"
echo "RPC_PORT: $RPC_PORT"
echo "SEED_NODE: $SEED_NODE"
echo "PROJECT: $PROJECT"
echo "WITNESS_NODE: $WITNESS_NODE"
echo "CLI_WALLET: $CLI_WALLET"

echo "Begin Update..."
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
pip3 install autobahn pycrypto graphenelib 
python3 setup.py install --user

##################################################################################################
# Download the pre-compiled witness_node and cli_wallet provided by the trusted source for this  #
# the GRAPHENE TEST.                                                                             #
##################################################################################################
cd  /usr/bin/$WITNESS_NODE
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/$WITNESS_NODE
chmod +x $WITNESS_NODE

cd  /usr/bin/$CLI_WALLET
time wget https://rfxblobstorageforpublic.blob.core.windows.net/rfxcontainerforpublic/$CLI_WALLET
chmod +x $CLI_WALLET

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

python3 modify_config.py /home/$USER_NAME/graphene/witness_node/config.ini http://url.to/json_file

service $PROJECT start
