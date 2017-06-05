#!/bin/bash

set -e 

date
ps axjf

USER_NAME=$1
FQDN=$2
NPROC=$(nproc)
LOCAL_IP=`ifconfig|xargs|awk '{print $7}'|sed -e 's/[a-z]*:/''/'`
RPC_PORT=8090
P2P_PORT=1776
PROJECT=eos
GITHUB_REPOSITORY=https://github.com/eosio/eos.git
WITNESS_NODE=eosd
CLI_WALLET=eos_wallet

echo "USER_NAME: $USER_NAME"
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

##################################################################################################
# Install all necessary packages for building the project.                                       #
##################################################################################################
time apt -y install ntp g++ make cmake libbz2-dev libssl-dev autoconf automake libtool\
                     clang++-3.8 python-dev pkg-config libreadline-dev doxygen libncurses5-dev \

##################################################################################################
# Build Boost 1.60                                                                               #
##################################################################################################
cd /usr/local
wget -O boost_1_60_0.tar.gz http://sourceforge.net/projects/boost/files/boost/1.60.0/boost_1_60_0.tar.gz
tar -xf boost_1_60_0.tar.gz
cd boost_1_60_0
time ./bootstrap.sh --prefix=/usr/local/lib/boost_1_60_0
time ./b2 install
BOOST_ROOR=/usr/local/lib/boost_1_60_0
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
sed -i 's/add_subdirectory( tests )/#add_subdirectory( tests )/g' /usr/local/src/$PROJECT/CMakeLists.txt
time cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_COMPILER=/usr/bin/clang++-3.8 -DCMAKE_C_COMPILER=/usr/bin/clang-3.8 .
time make -j$NPROC

##################################################################################################
# Configure service. Enable it to start on boot.                                        #
##################################################################################################
cat >/lib/systemd/system/$PROJECT.service <<EOL
[Unit]
Description=Job that runs $PROJECT daemon
[Service]
Type=simple
Environment=statedir=/home/$USER_NAME/$PROJECT/producer_node
ExecStartPre=/bin/mkdir -p /home/$USER_NAME/$PROJECT/producer_node
ExecStart=/usr/bin/$WITNESS_NODE --data-dir /home/$USER_NAME/$PROJECT/producer_node
TimeoutSec=300
[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable $PROJECT
service $PROJECT start

##################################################################################################
# TODO: Directions to connect to wallet and interact with network.                               #
##################################################################################################
