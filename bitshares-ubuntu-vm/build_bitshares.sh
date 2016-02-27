#!/bin/bash

# print commands and arguments as they are executed
set -x

#echo "starting ubuntu devbox install on pid $$"
date
ps axjf

#################################################################
# Update Ubuntu and install prerequisites for running BitShares #
#################################################################
time apt-get -y update
time apt-get install -y bitshares dphys-swapfile ntp

if [ $1 = 'Build' ]; then
#################################################################
# Build BitShares from source                                   #
#################################################################
NPROC=$(nproc)
echo "nproc: $NPROC"
#################################################################
# Install all necessary packages for building BitShares         #
#################################################################
#time apt-get && apt-get -y install git cmake libbz2-dev libdb++-dev libdb-dev libssl-dev openssl libreadline-dev autoconf libtool libboost-all-dev

#cd /usr/local
#time git clone https://github.com/bitshares/bitshares-2.git
#cd bitshares-2/
#time git submodule update --init --recursive --force
#time cmake -DCMAKE_BUILD_TYPE=Release .
#time make -j$NPROC
#
#printf '%s\n%s\n' '#!/bin/sh' '/usr/local/bitshares-2/programs/witness_node/witness_node --rpc-endpoint=127.0.0.1:8090' >> /etc/init.d/bitshares
#chmod +x /etc/init.d/bitshares
#update-rc.d bitshares defaults

else    
#################################################################
# Install BitShares from PPA                                    #
#################################################################
time add-apt-repository -y ppa:bitshares/bitshares
time apt-get -y update
time apt-get install -y bitshares
fi

#################################################################
# Configure BitShares witeness node to auto start at boot       #
#################################################################
printf '%s\n%s\n' '#!/bin/sh' '/usr/local/bitshares-2/programs/witness_node/witness_node --rpc-endpoint=127.0.0.1:8090' >> /etc/init.d/bitshares
chmod +x /etc/init.d/bitshares
update-rc.d bitshares defaults

#################################################################
# BitShares installed. Reboot to start the witness node         #
#################################################################
reboot

#################################################################
# Connect to the host via SSH, then start cli wallet            #
# sudo /usr/local/bitshares-2/programs/cli_wallet/cli_wallet    #
#################################################################