@description('Azure region for the Recovery Services vault.')
param location string

@description('Deployment environment.')
param environment string

@description('Recovery Services vault name.')
param vaultName string

resource recoveryVault 'Microsoft.RecoveryServices/vaults@2026-01-01' = {
  name: vaultName
  location: location

  tags: {
    Environment: environment
    ManagedBy: 'Bicep'
    Project: 'AZ104-Lab'
  }

  sku: {
    name: 'Standard'
  }

  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

output vaultId string = recoveryVault.id
output vaultName string = recoveryVault.name
output vaultLocation string = recoveryVault.location
