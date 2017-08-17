# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "742e386a-f119-40b4-93cf-58b1efaf41ea"
    client_id       = "f0e814df-a96d-4d6d-a289-5f75deaf25a3"
    client_secret   = "sWOANsYR+n8nYzbw6uM5mqu1dj9aWMkDg5GNl4YjlFQ="
    tenant_id       = "72f988bf-86f1-41af-91ab-2d7cd011db47"
} 

# Create a resource group
resource "azurerm_resource_group" "rg" {
    name     = "${var.resource_group}"
    location = "${var.location}"
}

# Create a virtual network in the web_servers resource group
resource "azurerm_virtual_network" "vnet" {
    name                = "${var.virtual_network_name}"
    location            = "${azurerm_resource_group.rg.location}"
    address_space       = ["${var.address_space}"]
    resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnet" {
    name                 = "${azurerm_resource_group.rg.name}-subnet"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    address_prefix       = "${var.subnet_prefix}"
}

resource "azurerm_subnet" "subnet2" {
    name                 = "${azurerm_resource_group.rg.name}-subnet2"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    address_prefix       = "${var.subnet2_prefix}"
}


# Create a public IP
resource "azurerm_public_ip" "pip" {
    name                         = "${azurerm_resource_group.rg.name}-ip"
    location                     = "${var.location}"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "Dynamic"
    #domain_name_label            = "${var.dns_name}"
}

    # Create an application gateway
resource "azurerm_application_gateway" "network" {
    name                = "${azurerm_virtual_network.vnet.name}"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    sku {
        name           = "Standard_Small"
        tier           = "Standard"
        capacity       = 2
    }
    gateway_ip_configuration {
        name         = "${azurerm_virtual_network.vnet.name}-gwip-cfg"
        subnet_id    = "${azurerm_virtual_network.vnet.id}/subnets/${azurerm_subnet.subnet.name}"
    }
    frontend_port {
        name         = "${azurerm_virtual_network.vnet.name}-feport"
        port         = 80
    }
    frontend_ip_configuration {
        name         = "${azurerm_virtual_network.vnet.name}-feip"  
        public_ip_address_id = "${azurerm_public_ip.pip.id}"
    }
    backend_address_pool {
        name = "${azurerm_virtual_network.vnet.name}-beap"
    }
    backend_http_settings {
        name                  = "${azurerm_virtual_network.vnet.name}-be-htst"
        cookie_based_affinity = "Disabled"
        port                  = 80
        protocol              = "Http"
        request_timeout        = 1
    }
    http_listener {
        name                                  = "${azurerm_virtual_network.vnet.name}-httplstn"
        frontend_ip_configuration_name        = "${azurerm_virtual_network.vnet.name}-feip"
        frontend_port_name                    = "${azurerm_virtual_network.vnet.name}-feport"
        protocol                              = "Http"
    }
    request_routing_rule {
        name                       = "${azurerm_virtual_network.vnet.name}-rqrt"
        rule_type                  = "Basic"
        http_listener_name         = "${azurerm_virtual_network.vnet.name}-httplstn"
        backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap"
        backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"
    }
}

#
#   VM Configuration
#

# Create a NIC
resource "azurerm_network_interface" "nic" {
    name                = "${azurerm_resource_group.rg.name}-nic"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    ip_configuration {
        name                          = "${azurerm_resource_group.rg.name}-ipconfig"
        subnet_id                     = "${azurerm_subnet.subnet2.id}"
        private_ip_address_allocation = "Dynamic"
    }
}

# Create Storage Account
resource "azurerm_storage_account" "stor" {
    name                = "${var.dns_name}stor"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    account_type        = "${var.storage_account_type}"
}

# Create a Data Disk
resource "azurerm_managed_disk" "datadisk" {
    name                 = "${var.hostname}-datadisk"
    location             = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    storage_account_type = "Standard_LRS"
    create_option        = "Empty"
    disk_size_gb         = "1023"
}

# Create a VM
# Attach previous VM objects into the VM
resource "azurerm_virtual_machine" "vm" {
    name                  = "${azurerm_resource_group.rg.name}-vm"
    location              = "${azurerm_resource_group.rg.location}"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    vm_size               = "${var.vm_size}"
    network_interface_ids = ["${azurerm_network_interface.nic.id}"]

    storage_image_reference {
        publisher = "${var.image_publisher}"
        offer     = "${var.image_offer}"
        sku       = "${var.image_sku}"
        version   = "${var.image_version}"
    }

    storage_os_disk {
        name              = "${var.hostname}-osdisk"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    storage_data_disk {
        name              = "${var.hostname}-datadisk"
        managed_disk_id   = "${azurerm_managed_disk.datadisk.id}"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "1023"
        create_option     = "Attach"
        lun               = 0
    }

    os_profile {
        computer_name  = "${var.hostname}"
        admin_username = "${var.admin_username}"
        admin_password = "${var.admin_password}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = "${azurerm_storage_account.stor.primary_blob_endpoint}"
    }
}

