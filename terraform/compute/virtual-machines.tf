# Virtual Network for VMs
resource "azurerm_virtual_network" "vm_vnet" {
  name                = "${var.resource_prefix}-vm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vm_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.resource_prefix}-vm-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate Network Security Group to Subnet
resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Public IP for VM (Development)
resource "azurerm_public_ip" "vm_dev_ip" {
  name                = "${var.resource_prefix}-vm-dev-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(var.common_tags, {
    Environment = "Development"
    Purpose     = "VM Development Access"
  })
}

# Network Interface for Development VM
resource "azurerm_network_interface" "vm_dev_nic" {
  name                = "${var.resource_prefix}-vm-dev-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.common_tags, {
    Environment = "Development"
  })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_dev_ip.id
  }
}

# Data source to get the existing SSH key pair
data "azurerm_ssh_public_key" "azure_keys" {
  name                = "azure-keys"
  resource_group_name = var.resource_group_name
}

# Development VM - This will be subject to VM-specific policy
resource "azurerm_linux_virtual_machine" "development_vm" {
  name                = "${var.resource_prefix}-development-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  # These tags are REQUIRED by the VM policy
  tags = merge(var.common_tags, {
    Environment = "Development"
    Owner       = "Development Team"
    Department  = "IT"
    Project     = "VM-Governance-Demo"
    CostCenter  = "IT-DEV-001"
  })

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_dev_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.azurerm_ssh_public_key.azure_keys.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# Enterprise VM - This will be subject to Enterprise Initiative policies
resource "azurerm_network_interface" "vm_enterprise_nic" {
  name                = "${var.resource_prefix}-vm-enterprise-nic"
  location            = var.location
  resource_group_name = var.enterprise_rg.name

  tags = merge(var.common_tags, {
    Purpose = "Enterprise VM Network"
  })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "enterprise_vm" {
  name                = "${var.resource_prefix}-enterprise-vm"
  location            = var.location
  resource_group_name = var.enterprise_rg.name
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  # These tags are REQUIRED by the Enterprise Initiative
  tags = merge(var.common_tags, {
    Environment = "Production"
    Owner       = "Enterprise Team"
    Department  = "IT"
    Project     = "Enterprise-Governance-Demo"
    CostCenter  = "IT-PROD-001"
  })

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_enterprise_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.azurerm_ssh_public_key.azure_keys.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}