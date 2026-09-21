@description('Object ID of the managed identity receiving the RBAC role.')
param principalId string

@description('Stable Azure resource ID of the principal resource.')
param principalResourceId string

@description('Name of the existing Storage account.')
param storageAccountName string

var storageBlobDataReaderRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
)

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

resource storageBlobDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    storageAccount.id,
    principalResourceId,
    storageBlobDataReaderRoleId
  )
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataReaderRoleId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = storageBlobDataReader.id