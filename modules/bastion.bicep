param location string
param environment string
param bastionSubnetId string

param bastionName string = 'bas-az104-compute'
param publicIpName string = 'pip-bas-az104-compute'

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2025-01-01' = {
  name: publicIpName
  location: location

  sku: {
    name: 'Standard'
    tier: 'Regional'
  }

  properties: {
    publicIPAllocationMethod: 'Static'
  }

  tags: {
    Environment: environment
    ManagedBy: 'Bicep'
    Project: 'AZ104-Lab'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2025-01-01' = {
  name: bastionName
  location: location

  sku: {
    name: 'Basic'
  }

  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfiguration'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }

  tags: {
    Environment: environment
    ManagedBy: 'Bicep'
    Project: 'AZ104-Lab'
  }
}

output bastionName string = bastion.name