@description('Azure region used for the compute virtual network and private endpoint.')
param computeLocation string = resourceGroup().location

@description('Existing storage account used for private endpoint testing.')
param storageAccountName string

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Deployment environment.')
param environment string = 'dev'

@description('Address range reserved for private endpoints in the compute virtual network.')
param privateEndpointSubnetAddressPrefix string = '10.20.3.0/27'


// ------------------------------------------------------
// Existing compute network configuration + new PE subnet
// ------------------------------------------------------

module computeNetwork './modules/network.bicep' = {
  name: 'computeNetworkModule'

  params: {
    location: computeLocation
    environment: environment

    vnetName: 'vnet-az104-compute'
    vnetAddressPrefix: '10.20.0.0/16'

    subnetName: 'subnet-compute'
    subnetAddressPrefix: '10.20.1.0/24'

    bastionSubnetAddressPrefix: '10.20.2.0/26'
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix

    nsgName: 'nsg-az104-compute'
  }
}


// ------------------------------------------------------
// Storage private endpoint + private DNS
// ------------------------------------------------------

module storagePrivateEndpoint './modules/storage-private-endpoint.bicep' = {
  name: 'storagePrivateEndpointModule'

  params: {
    location: computeLocation
    environment: environment

    storageAccountName: storageAccountName

    privateEndpointSubnetId: computeNetwork.outputs.privateEndpointSubnetId
    vnetId: computeNetwork.outputs.vnetId
  }
}


// ------------------------------------------------------
// Outputs
// ------------------------------------------------------

output environment string = environment
output computeVnetName string = computeNetwork.outputs.vnetName
output storagePrivateEndpointName string = storagePrivateEndpoint.outputs.privateEndpointName
output storagePrivateDnsZoneName string = storagePrivateEndpoint.outputs.privateDnsZoneName