param location string
param environment string

param vnetName string
param vnetAddressPrefix string

param subnetName string
param subnetAddressPrefix string

@description('Address range reserved for Azure Bastion.')
param bastionSubnetAddressPrefix string = '10.20.2.0/26'

@description('Address range reserved for private endpoints.')
param privateEndpointSubnetAddressPrefix string = '10.20.3.0/27'

param nsgName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: nsgName
  location: location
  tags: {
    Environment: environment
    ManagedBy: 'Bicep'
    Project: 'AZ104-Lab'
  }
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-VNet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetName
  location: location
  tags: {
    Environment: environment
    ManagedBy: 'Bicep'
    Project: 'AZ104-Lab'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }

    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }

      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
        }
      }

      {
        name: 'subnet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetName string = subnetName

output subnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  subnetName
)

output nsgName string = nsg.name

output bastionSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  'AzureBastionSubnet'
)

output privateEndpointSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  'subnet-private-endpoints'
)