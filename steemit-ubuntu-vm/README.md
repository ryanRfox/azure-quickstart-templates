# Steem on Ubuntu 16.04 LTS VM

This template mines your desired name into the Steem _blogchain_. With your name successfully registered, you may begin posting messages and comments thru the included command line interface, or use your credentials at the [Steemit web interface](https://steemit.com). Steem is just a *Deploy to Azure* click away.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Fissue2%2Fsteemit-ubuntu-vm%2Fazuredeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Fissue2%2Fsteemit-ubuntu-vm%2Fazuredeploy.json" target="_blank"><img src="http://armviz.io/visualizebutton.png"/></a>

# What is Steem?

> Steem is a blockchain-based social media platform where anyone can earn rewards. 

# Deployment Process

1. Submit the Azure deployment template
1. Acquire your credentials
1. Begin blogging

# Template Parameters

When you click the *Deploy to Azure* icon above, you need to specify the following template parameters:

* `adminUsername`: This is the account for connecting to your Azure virtual machine running the Steem client.
* `adminPassword`: This is your password for the host.  Azure requires passwords to have one upper case, one lower case, a special character, and a number.
* `dnsLabelPrefix`: This is used as both the VM name and DNS name of your public IP address.  Please ensure it is unique within your subscription namespace.
* `desiredName`: This is the name you intend to mine into the Steem blockchain. [Verify your desired name is available](https://steemd.com/api/account/exists?name=myname).
* `vmSize`: This is the size of the VM to use. Recommendation: Mining a name is CPU intensive. Selecting a multi core instance will probabilistically reduce the time to successfully mine your desired name.

# What the Template Actually Does

1. *Download:* The Azure virtual machine downloads the [Steem source code](https://github.com/steemit/steem) from GitHub
1. *Build:* The Steem project gets built, configured and the `steem service` starts
1. *Mine:* Once the public blockchain is synced your desired name will be mined

# Getting Started Tutorial

1. Please check your [name availability](https://steemd.com/api/account/exists?name=myname) prior to submitting the template, as it must be unique
1. Click the `Deploy to Azure` icon above
1. Complete the template parameters, choose your resource group, accept the terms and click Create
1. Wait about 15 minutes for the VM to spin up and install the bits
1. Connect to the VM via SSH using the DNS name assigned to your Public IP
1. Launch the cli-wallet: `sudo ~/launch_steem_wallet.sh`
1. Assign a secure password `> set_password use_a_secure_password_here` (note: displayed on screen)
1. Unlock the wallet `> unlock my_secure_password_from_above` the prompt will change to `unlocked >>>`
1. Check the sync status of the blockchain `> info` 
⋅⋅1. Within the results, note the values for `"time"` and `"head_block_age"`
⋅⋅1. While syncing these values will be the time of the synced block and how old that block is
⋅⋅1. Syncing is complete when these values are just a few seconds old
1. Wait a couple of hours for your desired name to be mined on the blockchain
1. Check the status of your desired name within the Steem blockchain `> get_account my_desired_name` where my_desired_name is the name you supplied for `desiredName` in the template.
⋅⋅1. The response including `!accounts.empty(): Unknown account` indicates the name is not yet mined on the blockchain
⋅⋅1. A successful response will include your desired `"name"` field and the public key representing it
1. Import your account to the wallet
⋅⋅1. Ensure the wallet is unlocked
⋅⋅1. Use the private key from your ~/brain_key.json file `unlocked >>> import_key 5yourPrivateKeyStartsWith5...`
1. Exit to save the wallet using `ctrl-d` 
1. View your wallet: `nano ~/steem/cli_wallet/wallet.json`

# Documentation

Please review the [Steem documentation](https://steem.io) to learn more. 

# Licensing

Steem is Copyright (c) 2016 Steemit, Inc. with portions Copyright (c) 2015 Cryptonomex, Inc., and contributors as [documented here](https://github.com/Steemit/Steem/master/LICENSE.md). 

# Troubleshooting

* Check current status of `steem service` 
Issuing `service steem status` will return the current state of the steem daemon. Normal operation will return:
`Active: active (running)`
* The `steem service status` is inactive (dead)
If the response contains `Active: inactive (dead)` please start the service:
`service steem start`
* The `steem service` fails to start
If after attempting to start the steem service as above and the response remains `Active: inactive (dead)` please start the service with the addition of the `--resync-blockchain` switch:
`service steem start --resync-blockchain` 
This will drop the blockchain database and download it anew from network peers.
* The `cli_wallet` will not connect to withness_node
The `cli_wallet` has a dependency on the `steem.service` being in the 'Active: active (running)` state. Verify the current as noted above. 

