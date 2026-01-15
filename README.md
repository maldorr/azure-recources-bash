# AZURE-FULL-STACK-VM-WITH-VOLUME
## Bash Script (Azure CLI)
This project replicates an OpenStack full-stack deployment (Network, Security, VM, Volume, Floating IP) using native Azure CLI (Bash).

---

### ---------- PREREQUISITES ----------
```Bash
# Login to Azure
az login

# Select your subscription (if needed)
# az account set --subscription "your-id-here"
```
### ---------- VARIABLES ----------
```Bash

LOCATION="switzerlandnorth"
RESOURCE_GROUP="RG-OpenStack-Replica"

# Network Names (Matching HEAT: my_net, my_subnet)
VNET_NAME="my_private_network"
SUBNET_NAME="my_subnet"
PUBLIC_IP_NAME="my_floating_ip"
NSG_NAME="allow_ssh_ping"
NIC_NAME="my_interface"

# Storage Name (Matching HEAT: my_data_volume)
DISK_NAME="my_extra_disk"
DISK_SIZE_GB=1

# VM Details (Matching HEAT: My_Full_Server)
VM_NAME="My_Full_Server"
VM_SIZE="Standard_B1s"  # Similar to m1.tiny
IMAGE_URN="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# Credentials
ADMIN_USER="azureuser"
ADMIN_PASSWORD="SecurePass!123"
```
### ---------- RESOURCE GROUP ----------
```Bash

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"
```
### ---------- VNET + SUBNET ----------
```Bash

# 1. Create VNet and Subnet (192.168.100.0/24) in one step
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefix "192.168.0.0/16" \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix "192.168.100.0/24" \
  --location "$LOCATION"
```
### ---------- SECURITY GROUP (NSG) ----------
```Bash

# Create the NSG container
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NSG_NAME" \
  --location "$LOCATION"
```
```Bash

# Rule 1: Allow SSH (Port 22) - Matches HEAT tcp 22
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name "Allow-SSH" \
  --protocol Tcp \
  --direction Inbound \
  --priority 1001 \
  --source-address-prefixes "*" \
  --destination-port-ranges 22 \
  --access Allow

# Rule 2: Allow ICMP (Ping) - Matches HEAT protocol: icmp
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name "Allow-ICMP" \
  --protocol Icmp \
  --direction Inbound \
  --priority 1002 \
  --source-address-prefixes "*" \
  --access Allow
```
### ---------- PUBLIC IP (FLOATING IP) ----------
```Bash

az network public-ip create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PUBLIC_IP_NAME" \
  --location "$LOCATION" \
  --allocation-method Static \
  --sku Standard
```

### ---------- NETWORK INTERFACE (NIC) ----------
```Bash

az network nic create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NIC_NAME" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --network-security-group "$NSG_NAME" \
  --public-ip-address "$PUBLIC_IP_NAME" \
  --location "$LOCATION"
```
### ---------- STORAGE (EXTRA VOLUME) ----------
```Bash

# Matches HEAT resource: my_data_volume (Size: 1GB)
az disk create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DISK_NAME" \
  --size-gb $DISK_SIZE_GB \
  --sku Standard_LRS \
  --location "$LOCATION"
```
### ---------- VM CONFIGURATION & CREATION ----------
```Bash

# 1. Configure VM Base, OS, Image, NIC, and attach Volume
# Unlike PowerShell, Azure CLI handles this in one command.

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --size "$VM_SIZE" \
  --image "$IMAGE_URN" \
  --nics "$NIC_NAME" \
  --attach-data-disks "$DISK_NAME" \
  --admin-username "$ADMIN_USER" \
  --admin-password "$ADMIN_PASSWORD" \
  --location "$LOCATION"
```
### ---------- OUTPUTS ----------
```Bash

FINAL_IP=$(az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" --query "ipAddress" --output tsv)

echo "✅ VM Created Successfully"
echo "SSH Command: ssh $ADMIN_USER@$FINAL_IP"
echo "Volume Status: Attached (Managed by Azure)"
