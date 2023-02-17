param clusterName string
param logworkspaceid string
param aadGroupdIds array
param subnetId string
param identity object
param appGatewayResourceId string
param vmSize string
param osDiskSize int
param kubernetesVersion string
param clusterIdentity string
param clusterCount int
param agentPoolProfileName string
param agentPoolMode string
param agentPoolType string
//param appGatewayIdentityResourceId string

var dockerBridgeCidr = '172.17.0.1/16'
var dnsServiceIP = '192.168.100.10'
var serviceCidr = '192.168.100.0/24'
var networkPolicy = 'snsnetworkpolicy'
var outboundType = 'userDefinedRouting'
var networkPlugin = 'azure'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-07-01' = {
  name: clusterName
  location: resourceGroup().location
  identity: {
    type: clusterIdentity
    userAssignedIdentities: identity
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    nodeResourceGroup: '${clusterName}-aksInfraRG'
    podIdentityProfile: {
      enabled: false
    }
    dnsPrefix: '${clusterName}aks'
    agentPoolProfiles: [
      {
        name: agentPoolProfileName
        mode: agentPoolMode
        count: clusterCount
        vmSize: vmSize
        osDiskSizeGB: osDiskSize
        type: agentPoolType
        vnetSubnetID: subnetId
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      outboundType: outboundType
      dockerBridgeCidr: dockerBridgeCidr
      dnsServiceIP: dnsServiceIP
      serviceCidr: serviceCidr
      networkPolicy: networkPolicy
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    enableRBAC: true
    aadProfile: {
      adminGroupObjectIDs: aadGroupdIds
      enableAzureRBAC: true
      managed: true
      tenantID: subscription().tenantId
    }
    addonProfiles: {
      omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: logworkspaceid
        }
        enabled: true
      }
      azurepolicy: {
        enabled: true
      }
      ingressApplicationGateway: {
        enabled: true
        config: {
          applicationGatewayId: appGatewayResourceId
          effectiveApplicationGatewayId: appGatewayResourceId
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
    }
  }
}

output kubeletIdentity string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output ingressIdentity string = aksCluster.properties.addonProfiles.ingressApplicationGateway.identity.objectId
output keyvaultaddonIdentity string = aksCluster.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
