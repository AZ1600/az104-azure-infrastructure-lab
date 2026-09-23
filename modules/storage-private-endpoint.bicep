param location string
param environment string

@description('Name of the existing Storage account that will receive a private Blob endpoint.')
param storageAccountName string

@description('Resource ID of the subnet reserved for private endpoints.')
param privateEndpointSubnetId string

@description('Resource ID of the virtual network that should resolve the private Storage endpoint.')
param vnetId string

var storageDnsSuffix = az.environment().suffixes.storage
var privateDnsZoneName = 'privatelink.blob.${storageDnsSuffix}'
var privateEndpointName = 'pe-${storageAccountName}-blob'


// ------------------------------------------------------
// Existing storage account
// ------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}


// ------------------------------------------------------
// Private DNS zone
// ------------------------------------------------------

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'

  tags: {
    Environment: environment
    ManagedBy: 'Bicep'
    Project: 'AZ104-Lab'
  }
}


// ------------------------------------------------------
// Link private DNS zone to compute VNet
// ------------------------------------------------------

resource privateDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-${environment}-compute-vnet'
  location: 'global'

  properties: {
    registrationEnabled: false

    virtualNetwork: {
      id: vnetId
    }
  }
}


// ------------------------------------------------------
// Blob private endpoint
// ------------------------------------------------------

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: privateEndpointName
  location: location

  tags: {
    Environment: environment
    ManagedBy: 'Bicep'
    Project: 'AZ104-Lab'
  }

  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }

    privateLinkServiceConnections: [
      {
        name: 'storage-blob-connection'

        properties: {
          privateLinkServiceId: storageAccount.id

          groupIds: [
            'blob'
          ]

          requestMessage: 'Private Blob access for the AZ-104 infrastructure lab.'
        }
      }
    ]
  }
}


// ------------------------------------------------------
// Associate private endpoint with Blob private DNS zone
// ------------------------------------------------------

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = {
  parent: privateEndpoint
  name: 'default'

  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-private-dns'

        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}


// ------------------------------------------------------
// Outputs
// ------------------------------------------------------

output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
output privateDnsZoneName string = privateDnsZone.name
output privateDnsVnetLinkName string = privateDnsVnetLink.name