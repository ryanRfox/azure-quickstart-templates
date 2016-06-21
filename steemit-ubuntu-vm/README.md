# Steem Blockchain Node on Ubuntu VM

This template mines your desired name into the Steem blogchain. With your name successfully registered, you may begin posting messages thru the included CLI interface, or use the [Steemit web interface](https://steemit.com). Everything you need to get started using the Steem blockchain from the command line is included. First, the Azuer virtual machine downloads the [Steem source code](https://github.com/steemit/steem) from GitHub. Next, the project builds, configures and starts the `steem service` using your supplied Azure template values. Finally, the public blockchain is synced and your desired name will be mined. Please check your [name availability](https://steemd.com/api/account/exists?name=myname) proir to submitting the template, as it must be unique.

# Steemit witness node Ubuntu 16.04 LTS VM

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Fissue2%2Fsteemit-ubuntu-vm%2Fazuredeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Fissue2%2Fsteemit-ubuntu-vm%2Fazuredeploy.json" target="_blank"><img src="http://armviz.io/visualizebutton.png"/></a>

# What is Steem?

```
Steem is a blockchain-based social media platform where anyone can earn rewards. Learn more about <a href="https://steem.io">Steem</a>. 
```

# Template Parameters

When you click the Deploy to Azure icon above, you need to specify the following template parameters:

* `adminUsername`: This is the account for connecting to your Steem host.
* `adminPassword`: This is your password for the host.  Azure requires passwords to have One upper case, one lower case, a special character, and a number.
* `dnsLabelPrefix`: This is used as both the VM name and DNS name of your public IP address.  Please ensure an unique name.
* `desiredName`: This is the name you intend to mine on the Steem blockchain. [Verify your desired name is available](https://steemd.com/api/account/exists?name=myname).
* `vmSize`: This is the size of the VM to use.Recommendation: Mining a name is CPU intensive. Selecting a multi core instance will probabilistically reduce the time to successfully mine your desired name.

# Getting Started Tutorial

* Click the `Deploy to Azure` icon above
* Complete the template parameters, choose your resource group, accept the terms and click Create
* Wait about 15 minutes for the VM to spin up and install the bits
* Connect to the VM via SSH using the DNS name assigned to your Public IP
* Launch the cli-wallet: `sudo ~/launch_steem_wallet.sh`
* Assign a secure password `> set_password use_a_secure_password_here` (note: displayed on screen)
* Unlock the wallet `> unlock my_secure_password_from_above` the prompt will change to `unlocked >>>`
* Check the sync status of the blockchain `> info` 
* * Within the results, note the values for `"time"` and `"head_block_age"`
* * While syncing these values will be the time of the synced block and how old that block is
* * Syncing is complete when these values are just a few seconds old
* Wait a couple of hours for your desired name to be mined on the blockchain
* Check the status of your desired name within the Steem blockchain `> get_account my_desired_name` where my_desired_name is the name you supplied for `desiredName` in the template.
* * The response including `!accounts.empty(): Unknown account` indicates the name is not yet mined on the blockchain
* * A successful response will include your desired `"name"` field and the public key representing it
* Import your account to the wallet
* * Ensure the wallet is unlocked
* * Use the private key from your ~/brain_key.json file `unlocked >>> import_key 5yourPrivateKeyStartsWith5...`
* Exit to save the wallet using `ctrl-d` 
* View your wallet: `nano ~/steem/cli_wallet/wallet.json`
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
