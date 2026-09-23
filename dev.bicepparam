using './azuredeploy.bicep'

param environment = 'dev'

param computeLocation = 'denmarkeast'

param storageAccountName = 'az104lab2uvqlnnpoiad6'

param privateEndpointSubnetAddressPrefix = '10.20.3.0/27'