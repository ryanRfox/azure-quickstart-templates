# Steem Blockchain Node on Ubuntu VM

This template delivers the Steem network to your VM in about 15 mintues (PPA install).  Everything you need to get started using the Steem blockchain from the command line is included. 
You may select to build from source or install from the community provided Personal Package Archive (PPA).  Once installed, the 'witnes_node' will begin syncing the public blockchain. 
You may then connect via SSH to the VM and launch the 'cli-wallet' to interface with the blockchain.

# Steemit witness node Ubuntu 16.04 LTS VM

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Fissue2%2Fsteemit-ubuntu-vm%2Fazuredeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Fissue2%2Fsteemit-ubuntu-vm%2Fazuredeploy.json" target="_blank"><img src="http://armviz.io/visualizebutton.png"/></a>

# What is Steem?

```
Steem is an industrial-grade financial blockchain smart contracts platform.  Built using the latest in
industry research, Steem delivers a decentralized financial platform with speeds approaching NASDAQ. 
```

# Template Parameters

When you click the Deploy to Azure icon above, you need to specify the following template parameters:

* `adminUsername`: This is the account for connecting to your Steem host.
* `adminPassword`: This is your password for the host.  Azure requires passwords to have One upper case, one lower case, a special character, and a number.
* `dnsLabelPrefix`: This is used as both the VM name and DNS name of your public IP address.  Please ensure an unique name.
* `desiredName`: This is the name you intend to mine on the Steem blockchain. It must not yet exist on the Steem blockchain. Verify your desired name is available [here](https://steem.io/checkname).
* `installMethod`: This tells Azure how to install the software bits.  The default is using the community provided PPA.  You may choose to install from source, but be advised this method takes substantially longer to complete.
* `vmSize`: This is the size of the VM to use.  Recommendations: Use the A series for PPA installs, and D series for installations from source.  Notice: Once the blockchain is synced, resize your VM to A1, as the Steem witness_node requires a small resource footprint. 

# Getting Started Tutorial

* Click the `Deploy to Azure` icon above
* Complete the template parameters, choose your resource group, accept the terms and click Create
* Wait about 15 minutes for the VM to spin up and install the bits
* Connect to the VM via SSH using the DNS name assigned to your Public IP
* Launch the cli-wallet: `sudo /usr/bin/cli_wallet --wallet-file=~/Steem/programs/cli-wallet/wallet.json`
* Assign a secure password `>set_password use_a_secure_password_here` (note: displayed on screen)
* `ctrl-d` will save the wallet and exit the client
* View your wallet: `nano ~/Steem/programs/cli-wallet/wallet.json`
* Wait a couple of hours for your desired name to be mined on the blockchain. 
* Learn more: [https://docs.steem.io](https://docs.steem.io)   

# Troubleshooting
* Check current status of `steem service` 
Issuing `service steem status` will return the current state of the steem daemon. Normal operation will return:
`Active: active (running)`
* The `steem serivce status` is inactive (dead)
If the response contains `Active: inactive (dead)` please start the service:
`service steem start`
* The `steem serivce` fails to start
If after attempting to start the steem service as above and the response remains `Active: inactive (dead)` please start the service with the addition of the `--resync-blockchain` switch:
`service steem start --resync-blockchain` 
This will drop the blockchain database and download it anew from network peers.
* The `cli_wallet` will not connect to withness_node
The `cli_wallet` has a dependency on the `steem.service` being in the 'Active: active (running)` state. Verify the current as noted above. 

# Licensing

Steem is Copyright (c) 2016 Steemit, Inc. with portions Copyright (c) 2015 Cryptonomex, Inc., and contributors as [documented here](https://github.com/Steemit/Steem/master/LICENSE.md). 

# More About Steem

Please review [Steem documentation](https://steem.io) to learn more. 