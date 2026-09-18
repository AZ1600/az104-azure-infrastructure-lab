using './azuredeploy.bicep'

param environment = 'dev'
param location = 'uksouth'
param computeLocation = 'denmarkeast'

param storagePrefix = 'az104lab'

param vnetName = 'vnet-az104-lab'
param vnetAddressPrefix = '10.10.0.0/16'

param subnetName = 'subnet-app'
param subnetAddressPrefix = '10.10.1.0/24'

param nsgName = 'nsg-az104-app'

param nicName = 'nic-az104-compute'

param vmName = 'vm-az104-ubuntu'
param vmSize = 'Standard_B1s'
param adminUsername = 'azureuser'

param sshPublicKey = readEnvironmentVariable('AZ104_SSH_PUBLIC_KEY')