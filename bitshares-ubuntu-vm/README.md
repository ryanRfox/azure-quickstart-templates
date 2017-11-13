# BitShares witness node CLI wallet on Ubuntu 17.10 VM

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Ffc_updates%2Fbitshares-ubuntu-vm%2Fazuredeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FryanRfox%2Fazure-quickstart-templates%2Ffc_updates%2Fbitshares-ubuntu-vm%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template uses the Azure Linux CustomScript extension to deploy a block producing VM on the BitShares Network containing both a witness node and command line interface (CLI) wallet.  The deployment template creates an Ubuntu 16.04 LTS VM, installs the BitShares witness node and CLI wallet.  The project will build from github source and configure the node for block production.