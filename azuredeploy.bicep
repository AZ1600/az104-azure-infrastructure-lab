@description('Azure region for the resources.')
param location string = resourceGroup().location

@description('Azure region used for the virtual machine and its regional networking.')
param computeLocation string = location

@description('Prefix used to generate the storage account name.')
param storagePrefix string = 'az104lab'

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Deployment environment.')
param environment string = 'dev'

@description('Virtual network name.')
param vnetName string = 'vnet-az104-lab'

@description('Virtual network address space.')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Subnet name.')
param subnetName string = 'subnet-app'

@description('Subnet address range.')
param subnetAddressPrefix string = '10.10.1.0/24'

@description('Network Security Group name.')
param nsgName string = 'nsg-az104-app'

@description('Network interface name.')
param nicName string = 'nic-az104-vm'

@description('Virtual machine name.')
param vmName string = 'vm-az104-ubuntu'

@description('Virtual machine size.')
param vmSize string = 'Standard_B1s'

@description('Administrator username.')
param adminUsername string = 'azureuser'

@secure()
@description('SSH public key used for the Linux VM.')
param sshPublicKey string

/*
module storage './modules/storage.bicep' = {
  name: 'storageModule'
  params: {
    location: location
    environment: environment
    storagePrefix: storagePrefix
  }
}
*/
/*
module network './modules/network.bicep' = {
  name: 'networkModule'
  params: {
    location: location
    environment: environment
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetName: subnetName
    subnetAddressPrefix: subnetAddressPrefix
    nsgName: nsgName
  }
}
*/

module computeNetwork './modules/network.bicep' = {
  name: 'computeNetworkModule'
  params: {
    location: computeLocation
    environment: environment
    vnetName: 'vnet-az104-compute'
    vnetAddressPrefix: '10.20.0.0/16'
    subnetName: 'subnet-compute'
    subnetAddressPrefix: '10.20.1.0/24'
    nsgName: 'nsg-az104-compute'
  }
}

module compute './modules/compute.bicep' = {
  name: 'computeModule'
  params: {
    location: computeLocation
    environment: environment
    nicName: nicName
    subnetId: computeNetwork.outputs.subnetId
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
  }
}

/*
output storageAccountName string = storage.outputs.storageAccountName
*/
output environment string = environment
output networkInterfaceName string = compute.outputs.nicName
output virtualMachineName string = compute.outputs.vmName