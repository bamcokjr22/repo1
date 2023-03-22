param routeTableName string
param routeName string
param location string
param routeTableAddressPrefix string
param routeTableNextHopType string
param routeTableNextHopIPAddress string
 
resource routeTable 'Microsoft.Network/routeTables@2021-02-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: routeName
        properties: {
          addressPrefix: routeTableAddressPrefix 
          nextHopType: routeTableNextHopType
          nextHopIpAddress: routeTableNextHopIPAddress
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
