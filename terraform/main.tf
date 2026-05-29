# ============================================================================
# Main Infrastructure — Azure Terraform + Ansible Lab
# ============================================================================
# This file provisions:
#   1. Networking (VNet, Subnet, NSG)
#   2. SSH Key Pair (via TLS provider)
#   3. Ansible Control VM (with cloud-init to install Ansible)
#   4. Application VMs (x3)
#   5. Azure AD Application + Service Principal + Role Assignment
# ============================================================================

# ---------- Data Source: Existing Resource Group ----------

# Resource Group (created by Terraform)
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ============================================================================
# 1. NETWORKING
# ============================================================================

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_address_prefixes
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "terraform-ansible-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  # Allow SSH from anywhere
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP from anywhere
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ============================================================================
# 2. SSH KEY PAIR
# ============================================================================

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally for SSH access
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/ssh_keys/id_rsa"
  file_permission = "0600"
}

# ============================================================================
# 3. ANSIBLE CONTROL VM
# ============================================================================

# Public IP for Control VM
resource "azurerm_public_ip" "control_vm_pip" {
  name                = "ansible-control-vm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
  tags                = var.tags
}

# NIC for Control VM
resource "azurerm_network_interface" "control_vm_nic" {
  name                = "ansible-control-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.control_vm_pip.id
  }
}

# Cloud-init script for Ansible Control VM
# Installs Ansible, copies SSH key, and prepares the control node
locals {
  cloud_init_control = <<-CLOUDINIT
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - software-properties-common
      - python3-pip
      - sshpass

    runcmd:
      - sudo apt-add-repository --yes --update ppa:ansible/ansible
      - sudo apt-get install -y ansible
      - mkdir -p /home/${var.admin_username}/.ssh
      - echo '${tls_private_key.ssh.private_key_pem}' > /home/${var.admin_username}/.ssh/id_rsa
      - chmod 600 /home/${var.admin_username}/.ssh/id_rsa
      - chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/.ssh
      - mkdir -p /home/${var.admin_username}/ansible
      - chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/ansible
      - echo "Ansible control node setup complete" > /home/${var.admin_username}/setup_complete.txt
  CLOUDINIT
}

# Ansible Control VM
resource "azurerm_linux_virtual_machine" "control_vm" {
  name                            = "ansible-control-vm"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  custom_data                     = base64encode(local.cloud_init_control)
  zone                            = "1"
  tags                            = var.tags

  network_interface_ids = [
    azurerm_network_interface.control_vm_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "ansible-control-vm-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# ============================================================================
# 4. APPLICATION VMs (x3)
# ============================================================================

# NICs for App VMs (no public IP — accessed via control VM over private network)
resource "azurerm_network_interface" "app_vm_nic" {
  count               = var.app_vm_count
  name                = "app-vm-${count.index + 1}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


# Application VMs
resource "azurerm_linux_virtual_machine" "app_vm" {
  count                           = var.app_vm_count
  name                            = "app-vm-${count.index + 1}"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  zone                            = "1"
  tags                            = var.tags

  network_interface_ids = [
    azurerm_network_interface.app_vm_nic[count.index].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "app-vm-${count.index + 1}-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}


