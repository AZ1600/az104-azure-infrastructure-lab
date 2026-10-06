@description('Azure region containing the VM that will be protected.')
param backupLocation string = 'denmarkeast'

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Deployment environment.')
param environment string = 'dev'

@description('Recovery Services vault name.')
param recoveryVaultName string = 'rsv-az104-backup-denmarkeast'

module recoveryVault './modules/recovery-vault.bicep' = {
  name: 'recoveryVaultModule'

  params: {
    location: backupLocation
    environment: environment
    vaultName: recoveryVaultName
  }
}

output recoveryVaultId string = recoveryVault.outputs.vaultId
output recoveryVaultName string = recoveryVault.outputs.vaultName
output recoveryVaultLocation string = recoveryVault.outputs.vaultLocation
