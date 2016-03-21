#!/bin/bash

set -e 

date
ps axjf

ip=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
FQDN=$2
echo "FQDN: $FQDN"
echo "eth0: $ip"

#################################################################
# Update Ubuntu and install prerequisites for running BitShares #
#################################################################
time apt-get update
time apt-get install -y ntp apache2

if [ $1 = 'From_Source' ]; then
#################################################################
# Build BitShares from source                                   #
#################################################################
NPROC=$(nproc)
echo "nproc: $NPROC"
#################################################################
# Install all necessary packages for building BitShares         #
#################################################################
time apt-get -y install git cmake libbz2-dev libdb++-dev libdb-dev libssl-dev openssl libreadline-dev autoconf libtool libboost-all-dev

cd /usr/local
time git clone https://github.com/bitshares/bitshares-2.git
cd /usr/local/bitshares-2
time git submodule update --init --recursive
time cmake -DCMAKE_BUILD_TYPE=Release .
time make -j$NPROC
cp /usr/local/bitshares-2/programs/witness_node/witness_node /usr/bin/witness_node
cp /usr/local/bitshares-2/programs/cli_wallet/cli_wallet /usr/bin/cli_wallet

else    
#################################################################
# Install BitShares from PPA                                    #
#################################################################
time add-apt-repository -y ppa:bitshares/bitshares
time apt-get -y update
time apt-get install -y bitshares2-cli bitshares2

fi

#################################################################
# Build the UI codebase                                         #
#################################################################
#

#################################################################
# Configure UI to default to this VM (Replaces OpenLedger)      #
#################################################################
#sed -i "s@connection: ""wss://bitshares.openledger.info/ws""@connection: ""ws://$FQDN:8090/ws""@" "/dl/src/stores/SettingsStore.js"
#sed -i "s@connection: [@connection: [\n                ""ws://$FQDN:8090/ws"",@" "/dl/src/stores/SettingsStore.js"

#################################################################
# Configure webserver for UI                                    #
#################################################################
printf '<VirtualHost *:80>\n  DocumentRoot /usr/share/bitshares2-ui\n  ErrorLog ${APACHE_LOG_DIR}/error.log\n  CustomLog ${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>'>> /etc/apache2/sites-available/bitshares2-ui.conf
a2dissite 000-default   # Disable the default Apache site
a2ensite bitshares2-ui  # Enable Bitshares2-ui site
service apache2 restart 

#################################################################
# Configure BitShares witeness node to auto start at boot       #
#################################################################
printf '%s\n%s\n' '#!/bin/sh' '/usr/bin/witness_node --rpc-endpoint='$ip':8090 -d /usr/local/bitshares-2/programs/witness_node/'>> /etc/init.d/bitshares
chmod +x /etc/init.d/bitshares
update-rc.d bitshares defaults
/etc/init.d/bitshares & exit 0

##################################################################################################
# Connect to the web wallet by pointing your web browser to:                                     #
# http://<VMname>.<region>.cloudapp.azure.com                                                    #
# The fully qualified domain name (FQDN) can be found within the Azure Portal under "DNS name"   #
# Learn more: http://docs.bitshares.eu                                                           #
#                                                                                                #
# Connect to host via SSH, then start cli wallet:                                                #
# $sudo /usr/bin/cli_wallet --wallet-file=/usr/local/bitshares-2/programs/cli-wallet/wallet.json #
# >set_password use_a_secure_password_but_check_your_shoulder_as_it_will_be_displayed_on_screen  #
# >ctrl-d [will save the wallet and exit the client]                                             #
# $nano /usr/local/bitshares-2/programs/cli-wallet/wallet.json                                   #
# Learn more: http://docs.bitshares.eu                                                           #
##################################################################################################
