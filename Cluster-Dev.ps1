# $subscriptionID = "SOC Operations"
# $resourceGroup = "bastion-rg"
# $vmName = "soc-ops-bastion"
# az account set --subscription $subscriptionID
# # az ssh vm -n $vmName -g $resourceGroup --prefer-private-ip
# az ssh vm --ip sshaccessgw-ops.usgovvirginia.cloudapp.usgovcloudapi.net

$tenant = '7fb6a3f6-00e2-4f99-8667-e3de74600826'

## Ops Subscription for DNS configuration
$opssubscriptionName = "SOC Operations"
$opssubscriptionID = '1ef3cdca-be25-4459-9446-9ebc7199bfe1'
$opsVNETrg = 'prd-ops-global-network-usva-rg'
$opsVNET = 'prd-ops-global-network-usva-vnet'

## Subscription where Cluster is to be built & Cluster info
$subscriptionName = 'SOC Development'
$subscriptionID = '42ac9d15-d4a5-466d-a2f3-fc60699e7d06'
$vnetrg = 'dev-cst-soc-network-usva-rg'
$vnet = 'dev-cst-soc-network-usva-vnet-001'
$subnetname = 'k8s'
$zoneName = 'privatelink.usgovvirginia.cx.aks.containerservice.azure.us'
$resourceGroup = 'dev-cst-aks-usva-rg'
$noderesourceGroup = 'dev-cst-node-usva-rg'
$logsresourceGroup = 'dev-cst-log-usva-rg'
$clusterName = 'dev-cst'
$region = 'usgovvirginia'
$dataNodeVMsku = 'Standard_D8s_v3'
# $asProfile = '' ## AUTOSCALE PROFILE - TODO
$networkContributor = $(az role definition list --name 'Network Contributor' --query "[0].id")
$dnsZoneContributor = $(az role definition list --name 'Private DNS Zone Contributor' --query "[0].id")
$aadAdminGroupID = '8280df02-cd51-4b8a-8936-d9d96a8cf042,3fac15d2-f410-4fdd-a554-3a6cb2663b6f'
# $outFilePath = [Environment]::GetFolderPath("Desktop")+'\SOC-IAC\k8s-deployment\.dat\dev'    ### FOR TESTING
$tags = '"foo=bar" "baz=qux"'


# az aks install-cli
# az login --tenant $tenant
az account set --subscription $subscriptionName

## Add Providers to Subscription
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights

## Build Resource Groups ($noderesourceGroup built by aks)
az group create --name $resourceGroup `
    --location $region
az group create --name $logsresourceGroup `
    --location $region

# Create User Managed Identity for Kubernetes
az identity create `
  --name $clusterName `
  --resource-group $resourceGroup

# Get Principal ID of Identity
$aksPrincipalId = $(
  az identity show `
   --name $clusterName `
   --resource-group $resourceGroup `
   --query 'principalId' `
   --output tsv
  )
# Get ID of Identity
$aksId = $(
  az identity show `
   --name $clusterName `
   --resource-group $resourceGroup `
   --query 'id' `
   --output tsv
  )

# Get the ID of the AKS VNET for Identity Permissions
$vnetId=$(
  az network vnet show `
   --resource-group $vnetrg `
   --name $vnet `
   --subscription $subscriptionID `
   --query 'id' `
   --output tsv
   )

# Network Contributor role on the VNET
az role assignment create --assignee $aksPrincipalId `
  --role $networkContributor `
  --scope $vnetId

# Set Environment to OPS
az account set --subscription $opssubscriptionName
# Get DNS Zone ID for Identity Permissions
$dnsZoneId=$(
  az network private-dns zone show `
   --resource-group $opsVNETrg `
   --name $zoneName `
   --subscription $opssubscriptionID `
   --query 'id' `
   --output tsv
)

# Private DNS Zone Contributor role on the DNS Zone
az role assignment create --assignee $aksPrincipalId `
  --role $dnsZoneContributor `
  --scope $dnsZoneId

# # Private Container - DNS Zone
# az role assignment create --assignee $aksPrincipalId `
#   --role $dnsZoneContributor `
#   --scope $dnsZoneId `
#   -o yaml >> $outFilePath'\rolednscontrib.yml'
# # Private Data - DNS Zone
# az role assignment create --assignee $aksPrincipalId `
#   --role $dnsZoneContributor `
#   --scope $dnsZoneId `
#   -o yaml >> $outFilePath'\rolednscontrib.yml'

# Set Environment back to Current
az account set --subscription $subscriptionName

# AKS Cluster Subnet
$subnetnameId = $(az network vnet subnet list --resource-group $vnetrg --vnet-name $vnet --query "[?name=='$subnetname'].id" -o tsv)

## Build Log Management
az monitor log-analytics workspace create `
  --resource-group $logsresourceGroup `
  --workspace-name $clusterName `
  --location $region `
  --ingestion-access Disabled `
  --query-access Disabled `
  --retention-time 30

$workspaceID = $(az monitor log-analytics workspace show --resource-group $logsresourceGroup --workspace-name $clusterName --query "id")

az aks create --name $clusterName `
    --resource-group $resourceGroup `
    --generate-ssh-keys `
    --kubernetes-version 1.23.8 `
    --zones 1 2 3 `
    --auto-upgrade-channel none `
    --enable-defender `
    --enable-addons monitoring `
    --workspace-resource-id $workspaceID `
    --os-sku Ubuntu `
    --node-resource-group $noderesourceGroup `
    --node-vm-size $dataNodeVMsku `
    --nodepool-name admin `
    --node-count 3 `
    --min-count 3 `
    --max-count 9 `
    --max-pods 100 `
    --enable-cluster-autoscaler `
    --vm-set-type VirtualMachineScaleSets `
    --network-plugin kubenet `
    --vnet-subnet-id $subnetnameId `
    --load-balancer-sku standard `
    --enable-private-cluster `
    --private-dns-zone $dnsZoneId `
    --fqdn-subdomain $clusterName `
    --aci-subnet-name $subnetname `
    --docker-bridge-address 172.23.0.0/16 `
    --pod-cidr 172.24.0.0/16 `
    --service-cidr 172.25.0.0/16 `
    --dns-service-ip 172.25.0.10 `
    --enable-aad `
    --enable-azure-rbac `
    --aad-admin-group-object-ids $aadAdminGroupID `
    --aad-tenant-id $tenant `
    --node-osdisk-type Ephemeral `
    --node-osdisk-size 30 `
    --enable-fips-image `
    --enable-managed-identity `
    --assign-identity $aksId `
    --uptime-sla `
    --yes


## ADDONS
az config set extension.use_dynamic_install=yes_without_prompt # allow addon installation w/o prompt
az aks addon enable -a azure-policy -n $clusterName -g $resourceGroup
az aks addon enable -a azure-keyvault-secrets-provider -n $clusterName -g $resourceGroup

## VM size options
#     Sizes          CPU   RAM    #NICS   Bandwidth (mbps)
# Standard_F2s_v24	  2	    4	 		  2     5000
# Standard_F4s_v2	    4	    8	 	  	2	    10000
# Standard_F8s_v2	    8	    16	    4	    12500
# Standard_F16s_v2	  16	  32	 	  4	    12500
# Standard_F32s_v2	  32	  64	  	8	    16000
# Standard_F48s_v2	  48	  96	  	8	    21000
# Standard_F64s_v2	  64	  128	  	8	    28000


#### MINIMAL NODES

az aks nodepool add `
    -g $resourceGroup `
    -n minhotpool `
    --cluster-name $clusterName `
    --os-sku Ubuntu `
    --enable-fips-image `
    --node-osdisk-type Ephemeral `
    --node-osdisk-size 30 `
    --node-vm-size Standard_D16ds_v5 `
    --enable-cluster-autoscaler `
    --min-count 3 `
    --max-count 5 `
    --node-count 3 `
    --zones 1 2 3

az aks nodepool add `
    -g $resourceGroup `
    -n mincoldpool `
    --cluster-name $clusterName `
    --os-sku Ubuntu `
    --enable-fips-image `
    --node-vm-size Standard_D16ds_v5 `
    --enable-cluster-autoscaler `
    --min-count 3 `
    --max-count 5 `
    --node-count 3 `
    --zones 1 2 3

az aks nodepool add `
    -g $resourceGroup `
    -n minmiscpool `
    --cluster-name $clusterName `
    --os-sku Ubuntu `
    --enable-fips-image `
    --node-vm-size Standard_D16ds_v5 `
    --enable-cluster-autoscaler `
    --min-count 3 `
    --max-count 5 `
    --node-count 3 `
    --zones 1 2 3

# az aks nodepool add `
#     -g $resourceGroup `
#     -n hotpool `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-osdisk-type Ephemeral `
#     --node-osdisk-size 30 `
#     --node-vm-size Standard_F48s_v2 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3

# az aks nodepool add `
#     -g $resourceGroup `
#     -n warmpool `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-vm-size Standard_D32ds_v5 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3

# az aks nodepool add `
#     -g $resourceGroup `
#     -n coldpool `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-vm-size Standard_D32ds_v5 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3

# az aks nodepool add `
#     -g $resourceGroup `
#     -n miscpool `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-vm-size Standard_D16ds_v5 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3

# #### Testing Nodes for size reduction

# # TO ADD:
# # --mode User `
# # --max-pods 150   ?
# az aks nodepool add `
#     -g $resourceGroup `
#     -n hotpool0 `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-osdisk-type Ephemeral `
#     --node-osdisk-size 30 `
#     --node-vm-size Standard_F32s_v2 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3

# az aks nodepool add `
#     -g $resourceGroup `
#     -n warmpool0 `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-vm-size Standard_D16ds_v5 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3

# az aks nodepool add `
#     -g $resourceGroup `
#     -n coldpool0 `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-vm-size Standard_D16ds_v5 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3

# az aks nodepool add `
#     -g $resourceGroup `
#     -n miscpool0 `
#     --cluster-name $clusterName `
#     --os-sku Ubuntu `
#     --enable-fips-image `
#     --node-vm-size Standard_D8ds_v5 `
#     --enable-cluster-autoscaler `
#     --min-count 3 `
#     --max-count 5 `
#     --node-count 3 `
#     --zones 1 2 3
