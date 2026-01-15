Step 1: Set Environment Variables
Copy and paste this block into your terminal. These variables control the naming of all resources to ensure they match the OpenStack equivalents.

Bash

# Location & Group
export LOCATION="switzerlandnorth"
export RESOURCE_GROUP="RG-OpenStack-Replica"

# Network (Neutron equivalents)
export VNET_NAME="my_private_network"
export SUBNET_NAME="my_subnet"
export PUBLIC_IP_NAME="my_floating_ip"
export NSG_NAME="allow_ssh_ping"
export NIC_NAME="my_interface"

# Storage (Cinder equivalent)
export DISK_NAME="my_extra_disk"
export DISK_SIZE_GB=1

# VM (Nova equivalent)
export VM_NAME="My_Full_Server"
export VM_SIZE="Standard_B1s"
export IMAGE_URN="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
export ADMIN_USER="azureuser"
Step 2: Create Resource Group
Create the container for all your resources.

Bash

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
Step 3: Configure Networking (Neutron)
3.1 Create VNet and Subnet
Creates my_private_network (192.168.0.0/16) and my_subnet (192.168.100.0/24).

Bash

az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefix "192.168.0.0/16" \
  --subnet-name $SUBNET_NAME \
  --subnet-prefix "192.168.100.0/24" \
  --location $LOCATION
3.2 Create Security Group (NSG) & Rules
Matches OpenStack Security Groups. We allow SSH (22) and ICMP (Ping).

Bash

# Create NSG
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name $NSG_NAME \
  --location $LOCATION

# Rule: Allow SSH
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name "Allow-SSH" \
  --protocol Tcp \
  --direction Inbound \
  --priority 1001 \
  --source-address-prefixes "*" \
  --destination-port-ranges 22 \
  --access Allow

# Rule: Allow Ping (ICMP)
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name "Allow-ICMP" \
  --protocol Icmp \
  --direction Inbound \
  --priority 1002 \
  --source-address-prefixes "*" \
  --access Allow
3.3 Create Public IP (Floating IP)
Allocates a static public IP address.

Bash

az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --location $LOCATION \
  --allocation-method Static \
  --sku Standard
3.4 Create Network Interface (Port)
Binds the Subnet, Security Group, and Public IP together into a virtual interface.

Bash

az network nic create \
  --resource-group $RESOURCE_GROUP \
  --name $NIC_NAME \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_NAME \
  --network-security-group $NSG_NAME \
  --public-ip-address $PUBLIC_IP_NAME \
  --location $LOCATION
Step 4: Create Storage (Cinder)
Creates an empty 1GB managed disk that will be attached to the VM later.

Bash

az disk create \
  --resource-group $RESOURCE_GROUP \
  --name $DISK_NAME \
  --size-gb $DISK_SIZE_GB \
  --sku Standard_LRS \
  --location $LOCATION
Step 5: Deploy Virtual Machine (Nova)
Creates the Ubuntu VM.

--nics: Attaches the Interface created in Step 3.4.

--attach-data-disks: Attaches the Volume created in Step 4.

Note: Replace SecurePass!123 with your desired password.

Bash

az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --size $VM_SIZE \
  --image $IMAGE_URN \
  --nics $NIC_NAME \
  --attach-data-disks $DISK_NAME \
  --admin-username $ADMIN_USER \
  --admin-password "SecurePass!123" \
  --location $LOCATION
Verification
To verify the deployment, run the following command to see your public IP:

Bash

az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --query "ipAddress" \
  --output tsv
You can now SSH into your VM using that IP: ssh azureuser@<YOUR_PUBLIC_IP>
