# Param (
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $aksName = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $aksRg = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $subscription = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $windowsUser = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [secureString] $windowsPassword = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $aksVnet = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $aksNetworkRgName = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $zoneNetworkRgName = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $zoneName = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $zoneSubscription = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $tenantId = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $devSecOpsGroupId = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $networkContributor = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $dnsZoneContributor = $null,
#     [ValidateNotNullOrEmpty()]
#     [Parameter(Mandatory = $true)] [string] $acrResourceId = $null
# )

$aksName = 'soc-dev-va-aks'
$aksRg = 'aks-dev-va-rg'
$subscription = '42ac9d15-d4a5-466d-a2f3-fc60699e7d06'
$location = 'usgovvirginia'
$aksVnet = 'soc-dev-va-vnet'
$aksNetworkRgName = 'network-va-rg'
$zoneNetworkRgName = 'dnszones-va-rg'
$zoneName = 'privatelink.usgovvirginia.cx.aks.containerservice.azure.us'
$zoneSubscription = '42ac9d15-d4a5-466d-a2f3-fc60699e7d06'
$tenantId = '7fb6a3f6-00e2-4f99-8667-e3de74600826'
$networkContributor = '4d97b98b-1d4f-4787-a291-c67834d212e7'
$dnsZoneContributor = 'b12aa53e-6015-4669-85d0-8515ebb3ae7f'
$acrResourceId = '/subscriptions/42ac9d15-d4a5-466d-a2f3-fc60699e7d06/resourceGroups/acr-dev-va-rg/providers/Microsoft.ContainerRegistry/registries/socdev'
$managedIdentityName = $aksName

az group create --name $aksRg --location $location

# Create User Managed Identity for Kubernetes
az identity create `
  --name $managedIdentityName `
  --resource-group $aksRg

# Get Principal ID of Identity
$aksPrincipalId = $(
  az identity show `
   --name $managedIdentityName `
   --resource-group $aksRg `
   --query 'principalId' `
   --output tsv
  )

# Get ID of Identity
$aksId = $(
  az identity show `
   --name $managedIdentityName `
   --resource-group $aksRg `
   --query 'id' `
   --output tsv
  )

# Get the ID of the AKS VNET for Identity Permissions
$vnetId=$(
  az network vnet show `
   --resource-group $aksNetworkRgName `
   --name $aksVnet `
   --subscription $subscription `
   --query 'id' `
   --output tsv
   )

# Network Contributor role on the VNET
az role assignment create --assignee $aksPrincipalId `
  --role $networkContributor `
  --scope $vnetId

# Get DNS Zone ID for Identity Permissions
$dnsZoneId=$(
  az network private-dns zone show `
   --resource-group $zoneNetworkRgName `
   --name $zoneName `
   --subscription $zoneSubscription `
   --query 'id' `
   --output tsv
)

# Private DNS Zone Contributor role on the DNS Zone
az role assignment create --assignee $aksPrincipalId `
  --role $dnsZoneContributor `
  --scope $dnsZoneId

# AKS Cluster Subnet
$subnetId=$(
  az network vnet subnet show `
    --name "aks" `
    --resource-group $aksNetworkRgName `
    --vnet-name $aksVnet `
    --subscription $subscription `
    --query 'id' `
    --output tsv
)

# Create the AKS Cluster
az aks create `
    --resource-group $aksRg `
    --subscription $subscription `
    --location $location `
    --name $aksName `
    --nodepool-name npsystem `
    --enable-cluster-autoscaler `
    --node-count 3 `
    --min-count 1 `
    --max-count 3 `
    --max-pods 100 `
    --load-balancer-sku standard `
    --enable-addons monitoring `
    --enable-private-cluster `
    --private-dns-zone $dnsZoneId `
    --fqdn-subdomain $aksName `
    --aad-tenant-id $tenantId `
    --generate-ssh-keys `
    --enable-aad `
    --enable-azure-rbac `
    --vm-set-type VirtualMachineScaleSets `
    --kubernetes-version 1.23.5 `
    --vnet-subnet-id $subnetId `
    --enable-managed-identity `
    --assign-identity $aksId `
    --docker-bridge-address 172.17.0.1/16 `
    --dns-service-ip 10.10.0.10 `
    --service-cidr 10.10.0.0/24 `
    --attach-acr $acrResourceId `
    --network-plugin kubenet `
    --zones 2

# Create the Linux User Node Pool    
az aks nodepool add `
    --name nplinux `
    --resource-group $aksRg `
    --subscription $subscription `
    --cluster-name $aksName `
    --enable-cluster-autoscaler `
    --os-type Linux `
    --mode User `
    --node-count 5 `
    --node-vm-size Standard_D8s_v3 `
    --min-count 1 `
    --max-count 5 `
    --max-pods 150
