#!/bin/bash

# .DESCRIPTION
#    This script prompts the user for all necessary configuration details, presents a summary for review,
#    and upon confirmation, deploys the resources to Azure using the Azure CLI.

# -----------------------------------------------------------------------------
# COLORS & FORMATTING
# -----------------------------------------------------------------------------
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== AZURE INFRASTRUCTURE DEPLOYMENT WIZARD ===${NC}"

# -----------------------------------------------------------------------------
# 1. AUTHENTICATION & SUBSCRIPTION
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Step 1: Authentication${NC}"

if az account show > /dev/null 2>&1; then
    echo -e "${GREEN}Already logged in.${NC}"
else
    az login -o none
fi

read -p "Enter your Subscription ID (leave empty to use default): " subscriptionId
if [[ -n "$subscriptionId" ]]; then
    az account set --subscription "$subscriptionId"
    echo -e "${GREEN}Subscription set to: $subscriptionId${NC}"
fi

# -----------------------------------------------------------------------------
# 2. INPUT COLLECTION
# -----------------------------------------------------------------------------

# --- Resource Group ---
echo -e "\n${YELLOW}Step 2: Resource Group Details${NC}"
while [[ -z "$rgName" ]]; do
    read -p "Enter Resource Group Name (e.g., RG-Project): " rgName
done

while [[ -z "$location" ]]; do
    read -p "Enter Location (e.g., switzerlandnorth, eastus): " location
done

# --- Networking ---
echo -e "\n${YELLOW}Step 3: Network Configuration${NC}"
read -p "Enter Virtual Network Name (e.g., MyVNet): " vnetName
read -p "Enter VNet Address Prefix (default: 10.0.0.0/16): " vnetPrefix
vnetPrefix=${vnetPrefix:-"10.0.0.0/16"}

read -p "Enter Subnet Name (e.g., MySubnet): " subnetName
read -p "Enter Subnet Address Prefix (default: 10.0.1.0/24): " subnetPrefix
subnetPrefix=${subnetPrefix:-"10.0.1.0/24"}

# --- Security (NSG) ---
echo -e "\n${YELLOW}Step 4: Security (NSG)${NC}"
read -p "Enter Network Security Group Name (e.g., MyNSG): " nsgName

declare -a nsgRules
while true; do
    read -p "Add an inbound security rule? (y/n): " addRule
    if [[ "$addRule" != "y" ]]; then break; fi

    read -p " - Rule Name (e.g., AllowSSH): " ruleName
    read -p " - Destination Port (e.g., 22): " rulePort
    read -p " - Protocol (Tcp/Udp/Icmp/Any) [default: Tcp]: " ruleProto
    ruleProto=${ruleProto:-"Tcp"}
    read -p " - Priority (100-4096) [default: 1000]: " rulePriority
    rulePriority=${rulePriority:-1000}

    # Store rule as a delimited string "Name:Port:Proto:Priority"
    nsgRules+=("$ruleName:$rulePort:$ruleProto:$rulePriority")
done

# --- Public IP ---
echo -e "\n${YELLOW}Step 5: Public IP${NC}"
read -p "Enter Public IP Name (e.g., MyPublicIP): " pipName
read -p "Enter SKU (Basic/Standard) [default: Standard]: " pipSku
pipSku=${pipSku:-"Standard"}

if [[ "$pipSku" == "Standard" ]]; then
    pipAlloc="Static"
    echo -e "${GRAY}Standard SKU requires Static allocation. Setting to Static automatically.${NC}"
else
    read -p "Enter Allocation Method (Static/Dynamic) [default: Dynamic]: " pipAlloc
    pipAlloc=${pipAlloc:-"Dynamic"}
fi

# --- NIC ---
echo -e "\n${YELLOW}Step 6: Network Interface${NC}"
read -p "Enter NIC Name (e.g., MyNIC): " nicName

# --- Virtual Machine ---
echo -e "\n${YELLOW}Step 7: Virtual Machine${NC}"
read -p "Enter VM Name (No underscores! e.g., My-VM): " vmName
while [[ -z "$vmSize" ]]; do
    read -p "Enter VM Size (e.g., Standard_B1s, Standard_D2s_v3): " vmSize
done

echo "Select OS Type:"
echo "1. Linux (Ubuntu 22.04 LTS)"
echo "2. Windows (Server 2019 Datacenter)"
read -p "Enter choice (1 or 2): " osChoice

read -p "Enter Admin Username (e.g., azureuser): " adminUser
read -s -p "Enter Admin Password: " adminPass
echo "" # Newline after silent input

# --- Storage / Data Disks ---
echo -e "\n${YELLOW}Step 8: Storage Options${NC}"
read -p "Do you want to attach an extra data disk? (y/n): " addDataDisk
if [[ "$addDataDisk" == "y" ]]; then
    read -p " - Enter Disk Name (e.g., DataDisk_01): " diskName
    read -p " - Enter Size in GB (e.g., 10): " diskSize
    read -p " - Enter SKU (Standard_LRS/Premium_LRS) [default: Standard_LRS]: " diskSku
    diskSku=${diskSku:-"Standard_LRS"}
fi

read -p "Do you want to create a separate Storage Account? (y/n): " addStorageAccount
if [[ "$addStorageAccount" == "y" ]]; then
    read -p " - Enter Storage Account Name (lowercase, numbers only): " saName
    read -p " - Enter SKU (Standard_LRS/Standard_GRS) [default: Standard_LRS]: " saSku
    saSku=${saSku:-"Standard_LRS"}
fi

# -----------------------------------------------------------------------------
# 3. REVIEW & CONFIRMATION
# -----------------------------------------------------------------------------
clear
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}       CONFIGURATION SUMMARY              ${NC}"
echo -e "${CYAN}==========================================${NC}"

echo -ne "Resource Group: "; echo -e "${GREEN}$rgName${NC}"
echo -ne "Location:       "; echo -e "${GREEN}$location${NC}"
echo "------------------------------------------"
echo "VNet:           $vnetName ($vnetPrefix)"
echo "Subnet:         $subnetName ($subnetPrefix)"
echo "NSG:            $nsgName"
if [ ${#nsgRules[@]} -gt 0 ]; then
    for rule in "${nsgRules[@]}"; do
        IFS=':' read -r rName rPort rProto rPrio <<< "$rule"
        echo -e "${GRAY}  - Rule: $rName | Port: $rPort | Pri: $rPrio${NC}"
    done
else
    echo -e "${GRAY}  - No extra rules defined.${NC}"
fi
echo "------------------------------------------"
echo "Public IP:      $pipName ($pipSku / $pipAlloc)"
echo "NIC:            $nicName"
echo "------------------------------------------"
echo "VM Name:        $vmName"
echo "VM Size:        $vmSize"
if [[ "$osChoice" == "1" ]]; then osLabel="Linux (Ubuntu)"; else osLabel="Windows"; fi
echo "OS Type:        $osLabel"
echo "Admin User:     $adminUser"
echo "------------------------------------------"
if [[ "$addDataDisk" == "y" ]]; then
    echo -e "${YELLOW}Extra Disk:     $diskName | $diskSize GB | $diskSku${NC}"
fi
if [[ "$addStorageAccount" == "y" ]]; then
    echo -e "${YELLOW}Storage Acct:   $saName | $saSku${NC}"
fi
echo -e "${CYAN}==========================================${NC}"

read -p "Is this configuration correct? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo -e "${RED}Deployment cancelled by user.${NC}"
    exit 0
fi

# -----------------------------------------------------------------------------
# 4. DEPLOYMENT
# -----------------------------------------------------------------------------
echo -e "\n${CYAN}Starting Deployment... this may take a few minutes.${NC}"

# 1. Resource Group
echo "Creating Resource Group '$rgName'..."
az group create --name "$rgName" --location "$location" -o none

# 2. Networking
echo "Creating Network Resources..."
# Create VNet and Subnet in one go
az network vnet create --resource-group "$rgName" --name "$vnetName" --address-prefix "$vnetPrefix" --subnet-name "$subnetName" --subnet-prefix "$subnetPrefix" -o none

# 3. NSG & Rules
echo "Creating Security Group '$nsgName'..."
az network nsg create --resource-group "$rgName" --name "$nsgName" -o none

if [ ${#nsgRules[@]} -gt 0 ]; then
    for rule in "${nsgRules[@]}"; do
        IFS=':' read -r rName rPort rProto rPrio <<< "$rule"
        echo "  Adding Rule: $rName"
        az network nsg rule create --resource-group "$rgName" --nsg-name "$nsgName" --name "$rName" --priority "$rPrio" --destination-port-ranges "$rPort" --protocol "$rProto" --access Allow --direction Inbound -o none
    done
fi

# 4. Public IP
echo "Creating Public IP '$pipName'..."
az network public-ip create --resource-group "$rgName" --name "$pipName" --sku "$pipSku" --allocation-method "$pipAlloc" -o none

# 5. NIC
echo "Creating Network Interface '$nicName'..."
az network nic create --resource-group "$rgName" --name "$nicName" --vnet-name "$vnetName" --subnet "$subnetName" --network-security-group "$nsgName" --public-ip-address "$pipName" -o none

# 6. Storage Account (Optional)
if [[ "$addStorageAccount" == "y" ]]; then
    echo "Creating Storage Account '$saName'..."
    az storage account create --resource-group "$rgName" --name "$saName" --sku "$saSku" --location "$location" --kind StorageV2 -o none
fi

# 7. Data Disk (Optional)
diskId=""
if [[ "$addDataDisk" == "y" ]]; then
    echo "Creating Data Disk '$diskName'..."
    diskId=$(az disk create --resource-group "$rgName" --name "$diskName" --size-gb "$diskSize" --sku "$diskSku" --location "$location" --query "id" -o tsv)
fi

# 8. VM Configuration & Creation
echo -e "${CYAN}Creating VM... (This is the longest step)${NC}"

# Determine Image URN
if [[ "$osChoice" == "1" ]]; then
    # Ubuntu 22.04 LTS Gen2
    imageUrn="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
else
    # Windows Server 2019 Datacenter
    imageUrn="MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest"
fi

# Build the create command
# Note: Since we pre-created the NIC, we pass --nics. We do not need to pass subnet/vnet here.
cmd="az vm create --resource-group $rgName --name $vmName --size $vmSize --image $imageUrn --admin-username $adminUser --admin-password $adminPass --nics $nicName --location $location"

# Attach data disk if created
if [[ -n "$diskId" ]]; then
    cmd="$cmd --attach-data-disks $diskId"
fi

# Execute VM creation
eval $cmd -o none

# -----------------------------------------------------------------------------
# 5. FINAL OUTPUT
# -----------------------------------------------------------------------------
echo -e "\n${GREEN}==========================================${NC}"
echo -e "${GREEN}       DEPLOYMENT SUCCESSFUL!             ${NC}"
echo -e "${GREEN}==========================================${NC}"

# Retrieve the actual IP
ipAddress=$(az network public-ip show --resource-group "$rgName" --name "$pipName" --query "ipAddress" -o tsv)

if [[ -z "$ipAddress" ]]; then
    echo "IP Address: (Dynamic IP will be assigned shortly)"
else
    echo -e "Public IP: ${CYAN}$ipAddress${NC}"
fi

if [[ "$osChoice" == "1" ]]; then
    echo "Connect via SSH: ssh $adminUser@$ipAddress"
else
    echo "Connect via RDP: $ipAddress"
fi
echo "=========================================="
