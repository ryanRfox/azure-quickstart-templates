#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
NPROC=$(nproc)
LOCAL_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
PROJECT=eos
GITHUB_REPOSITORY=https://github.com/eosio/eos.git
BUILD_TYPE=Debug
PRODUCER_NODE=eosd
CLI_WALLET=eos_wallet
RPC_PORT=8090
P2P_PORT=1776

echo "USER_NAME: $USER_NAME"
echo "FQDN: $FQDN"
echo "nproc: $NPROC"
echo "eth0: $LOCAL_IP"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "PROJECT: $PROJECT"
echo "BUILD_TYPE: $BUILD_TYPE"
echo "PRODUCER_NODE: $PRODUCER_NODE"
echo "CLI_WALLET: $CLI_WALLET"
echo "P2P_PORT: $P2P_PORT"
echo "RPC_PORT: $RPC_PORT"

echo "Begin Update..."
apt-get -y update || exit 1;
# To avoid intermittent issues with package DB staying locked when next apt-get runs
sleep 5;

##################################################################################################
# Install all necessary packages for building the project.                                       #
##################################################################################################
time apt -y install ntp make cmake libbz2-dev libssl-dev autoconf automake libtool\
                    python-dev pkg-config libreadline-dev doxygen libncurses5-dev

##################################################################################################
# Install clang 4.0 for Xenial.                                                                  #
##################################################################################################
cat <<EOL >> /etc/apt/sources.list
# LLVM Toolchain
deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-4.0 main
deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-4.0 main
EOL
wget -O - http://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -
apt-get -y update || exit 1;
sleep 5;
apt-get -y install clang-4.0 lldb-4.0 lld-4.0

##################################################################################################
# Build Boost 1.60                                                                               #
##################################################################################################
cd /usr/local
wget -O boost_1_60_0.tar.gz http://sourceforge.net/projects/boost/files/boost/1.60.0/boost_1_60_0.tar.gz
tar -xf boost_1_60_0.tar.gz
cd boost_1_60_0
time ./bootstrap.sh --prefix=/usr/local/lib/boost_1_60_0
time ./b2 install
PATH=$PATH:/usr/local/lib/boost_1_60_0
rm /usr/local/boost_1_60_0.tar.gz
rm -rd /usr/local/boost_1_60_0

##################################################################################################
# Build secp256k1-zkp.                                                                           #
##################################################################################################
cd /usr/local/src/
git clone https://github.com/cryptonomex/secp256k1-zkp.git 
cd secp256k1-zkp
./autogen.sh 
./configure --prefix=/usr --sbindir=/usr/bin --libexecdir=/usr/lib/libsecp256k1 \
            --sysconfdir=/etc --sharedstatedir=/usr/share/libsecp256k1 \
            --localstatedir=/var/lib/libsecp256k1 --disable-tests --with-gnu-ld
make 
make install

##################################################################################################
# Build the project.                                                                             #
##################################################################################################
echo "Clone $PROJECT project"
cd /usr/local/src
time git clone $GITHUB_REPOSITORY
cd $PROJECT
time git submodule update --init --recursive
sed -i 's%PRIVATE appbase%PRIVATE appbase native_contract%g' /usr/local/src/$PROJECT/programs/$PRODUCER_NODE/CMakeLists.txt
sed -i 's%#include <eos/chain_api_plugin/chain_api_plugin.hpp>%#include <eos/chain_api_plugin/chain_api_plugin.hpp>\n#include <eos/http_plugin/http_plugin.hpp>
\n#include <eos/native_system_contract_plugin/native_system_contract_plugin.hpp>%g' /usr/local/src/$PROJECT/programs/$PRODUCER_NODE/main.cpp


time cmake -DCMAKE_CXX_COMPILER=/usr/bin/clang++-4.0 -DCMAKE_C_COMPILER=/usr/bin/clang-4.0 \
           -DCMAKE_BUILD_TYPE=$BUILD_TYPE .
time make -j$NPROC

cp /usr/local/src/$PROJECT/programs/$PRODUCER_NODE/$PRODUCER_NODE /usr/bin/$PRODUCER_NODE

##################################################################################################
# Configure service. Enable it to start on boot.                                        #
##################################################################################################
cat >/lib/systemd/system/$PROJECT.service <<EOL
[Unit]
Description=Job that runs $PROJECT daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/$PROJECT/$PRODUCER_NODE
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/$PROJECT/$PRODUCER_NODE
ExecStart=/usr/bin/$PRODUCER_NODE --data-dir /home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir
TimeoutSec=300
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable $PROJECT
service $PROJECT start
service $PROJECT stop

cp /usr/local/src/$PROJECT/genesis.json /home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir/
sed -i 's%# genesis-json =%genesis-json =/home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir%g' /home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir/config.ini
sed -i 's%enable-stale-production = false%enable-stale-production = true%g' /home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir/config.ini
sed -i 's%# producer-id =%producer-id = {"_id":1}\nproducer-id = {"_id":2}\nproducer-id = {"_id":3}\nproducer-id = {"_id":4}\nproducer-id = {"_id":5}%g' /home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir/config.ini
sed -i 's%producer-id = {"_id":5}%producer-id = {"_id":5}\nproducer-id = {"_id":6}\nproducer-id = {"_id":7}\nproducer-id = {"_id":8}\nproducer-id = {"_id":9}\nproducer-id = {"_id":10}%g' /home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir/config.ini
sed -i 's%# plugin =%plugin = eos::producer_plugin\nplugin = eos::chain_api_plugin%g' /home/$USER_NAME/$PROJECT/$PRODUCER_NODE/data-dir/config.ini

service $PROJECT start

##################################################################################################
# TODO: Directions to connect to wallet and interact with network.                               #
##################################################################################################