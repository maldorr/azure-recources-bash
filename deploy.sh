
echo "---------- VARIABLES ----------"

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
VM_SIZE="Standard_B1s" # Similar to m1.tiny
IMAGE_URN="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# Credentials
ADMIN_USER="azureuser"
ADMIN_PASSWORD="SecurePass!123"

echo "---------- RESOURCE GROUP ----------"
echo "Creating Resource Group: $RESOURCE_GROUP..."

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

echo "---------- VNET + SUBNET ----------"
echo "Creating VNet and Subnet (192.168.100.0/24)..."

# In CLI, we can create the VNet and the first Subnet in one command
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefix "192.168.0.0/16" \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix "192.168.100.0/24" \
  --location "$LOCATION" \
  --output none

echo "---------- SECURITY GROUP (NSG) ----------"
echo "Creating NSG and Rules..."

# Create the NSG container
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NSG_NAME" \
  --location "$LOCATION" \
  --output none

# Rule 1: Allow SSH (Port 22) - Matches HEAT tcp 22
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name "Allow-SSH" \
  --protocol Tcp \
  --direction Inbound \
  --priority 1001 \
  --source-address-prefixes "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 22 \
  --access Allow \
  --output none

# Rule 2: Allow ICMP (Ping) - Matches HEAT protocol: icmp
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name "Allow-ICMP" \
  --protocol Icmp \
  --direction Inbound \
  --priority 1002 \
  --source-address-prefixes "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges "*" \
  --access Allow \
  --output none

echo "---------- PUBLIC IP (FLOATING IP) ----------"
echo "Creating Public IP..."

az network public-ip create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PUBLIC_IP_NAME" \
  --location "$LOCATION" \
  --allocation-method Static \
  --sku Standard \
  --output none

echo "---------- NETWORK INTERFACE (NIC) ----------"
echo "Creating NIC and binding Subnet, NSG, and Public IP..."

az network nic create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NIC_NAME" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --network-security-group "$NSG_NAME" \
  --public-ip-address "$PUBLIC_IP_NAME" \
  --location "$LOCATION" \
  --output none

echo "---------- STORAGE (EXTRA VOLUME) ----------"
echo "Creating Extra Disk (1GB)..."

# Matches HEAT resource: my_data_volume
az disk create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DISK_NAME" \
  --size-gb $DISK_SIZE_GB \
  --sku Standard_LRS \
  --location "$LOCATION" \
  --output none

echo "---------- VM CONFIGURATION & CREATION ----------"
echo "Creating VM (Ubuntu 22.04)..."

# This command combines the VM Config steps:
# 1. Sets OS/Image
# 2. Uses the pre-created NIC (--nics)
# 3. Attaches the extra volume (--attach-data-disks)
# 4. Sets credentials

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --size "$VM_SIZE" \
  --image "$IMAGE_URN" \
  --nics "$NIC_NAME" \
  --attach-data-disks "$DISK_NAME" \
  --admin-username "$ADMIN_USER" \
  --admin-password "$ADMIN_PASSWORD" \
  --location "$LOCATION" \
  --output json

