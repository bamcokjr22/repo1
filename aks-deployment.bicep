// targetScope = 'subscription'

// param location string = 'eastus'
param location string = resourceGroup().location
param resourcePrefix string = 'aksbicep1'

// var resourceGroupName = '${resourcePrefix}-rg'

// resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
//   name: resourceGroupName
//   location: location
// }

module aks 'aks-cluster.bicep' = {
  name: '${resourcePrefix}cluster'
  // scope: rg
  params: {
    location: location
    clusterName: resourcePrefix
  }
}

