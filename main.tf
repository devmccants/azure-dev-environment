# Specify the Azure Provider Source and Version
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Configure Development Environment Resources
resource "azurerm_resource_group" "mac-rg" {
  name     = "mac-resources"
  location = "East US"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "mac-vn" {
  name                = "dev-network"
  location            = azurerm_resource_group.mac-rg.location
  resource_group_name = azurerm_resource_group.mac-rg.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
}

resource "azurerm_subnet" "mac-sub" {
  name                 = "mac-subnet"
  resource_group_name  = azurerm_resource_group.mac-rg.name
  virtual_network_name = azurerm_virtual_network.mac-vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "mac-sg" {
  name                = "mac-dev-securitygroup"
  location            = azurerm_resource_group.mac-rg.location
  resource_group_name = azurerm_resource_group.mac-rg.name
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "mac-sr" {
  name                        = "mac-dev-securityrule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mac-rg.name
  network_security_group_name = azurerm_network_security_group.mac-sg.name
}

resource "azurerm_subnet_network_security_group_association" "mac-sga" {
  subnet_id                 = azurerm_subnet.mac-sub.id
  network_security_group_id = azurerm_network_security_group.mac-sg.id
}

resource "azurerm_public_ip" "mac-ip" {
  name                = "TestIP"
  resource_group_name = azurerm_resource_group.mac-rg.name
  location            = azurerm_resource_group.mac-rg.location
  allocation_method   = "Static"

  tags = {
    environmentt = "dev"
  }
}

resource "azurerm_network_interface" "mac-nic" {
  name                = "dev-nic"
  location            = azurerm_resource_group.mac-rg.location
  resource_group_name = azurerm_resource_group.mac-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mac-sub.id
    public_ip_address_id          = azurerm_public_ip.mac-ip.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "mac-vm" {
  name                = "dev-machine"
  resource_group_name = azurerm_resource_group.mac-rg.name
  location            = azurerm_resource_group.mac-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mac-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/macazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}