provider "azurerm" {
    subscription_id = "${var.subscription_id}"
    client_id       = "${var.client_id}"
    client_secret   = "${var.client_secret}"
    tenant_id       = "${var.tenant_id}"
} 

resource "azurerm_resource_group" "rg" {
    name     = "${var.resource_group}"
    location = "${var.location}"
}

resource "azurerm_virtual_network" "vnet" {
    name                = "${var.virtual_network_name}"
    location            = "${azurerm_resource_group.rg.location}"
    address_space       = ["10.254.0.0/16"]
    resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnet" {
    name                 = "${azurerm_resource_group.rg.name}-subnet"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    address_prefix       = "10.254.0.0/24"
}

resource "azurerm_subnet" "subnet2" {
    name                 = "${azurerm_resource_group.rg.name}-subnet2"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    address_prefix       = "10.254.1.0/24"
}

resource "azurerm_public_ip" "pip" {
    name                         = "${azurerm_resource_group.rg.name}-ip"
    location                     = "${azurerm_resource_group.rg.location}"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "Dynamic"
}

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
        ip_address_list = ["${element(azurerm_network_interface.nic.*.private_ip_address, count.index)}"] 
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

resource "azurerm_network_interface" "nic" {
    name                = "${azurerm_resource_group.rg.name}-nic"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    ip_configuration {
        name                          = "${azurerm_resource_group.rg.name}-ipconfig"
        subnet_id                     = "${azurerm_subnet.subnet2.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "10.254.1.4"
    }
}

#
# Subnet VM
#
resource "azurerm_virtual_machine" "vm" { 
    name                  = "${azurerm_resource_group.rg.name}-vm"
    location              = "${azurerm_resource_group.rg.location}"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    vm_size               = "${var.vm_size}"
    network_interface_ids = ["${azurerm_network_interface.nic.id}"]

    connection {
        type                = "ssh"
        bastion_host        = "${azurerm_public_ip.bastion_pip.fqdn}"
        bastion_user        = "${var.username}"
        bastion_private_key = "${file(var.private_key_path)}"
        host                = "${element(azurerm_network_interface.nic.*.private_ip_address, count.index)}"
        user                = "${var.username}"
        private_key         = "${file(var.private_key_path)}"
    }

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

    os_profile {
        computer_name  = "${var.hostname}"
        admin_username = "${var.username}"
        admin_password = "${var.password}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${file(var.public_key_path)}"
        }
    }

    provisioner "remote-exec" {
        inline = ["sudo apt-get update && sudo apt-get install nginx -y"]
    }
}

#
# Bastion Host
#
resource "azurerm_public_ip" "bastion_pip" {
    name                         = "${azurerm_resource_group.rg.name}-bastion-pip"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    location                     = "${azurerm_resource_group.rg.location}"
    public_ip_address_allocation = "Dynamic"
    domain_name_label            = "${azurerm_resource_group.rg.name}-bastion"
}

resource "azurerm_network_security_group" "bastion_nsg" {
    name                = "${azurerm_resource_group.rg.name}-bastion-nsg"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    security_rule {
        name                       = "allow_SSH_in_all"
        description                = "Allow SSH in from all locations"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "bastion_nic" {
    name                      = "${azurerm_resource_group.rg.name}-bastion-nic"
    location                  = "${azurerm_resource_group.rg.location}"
    resource_group_name       = "${azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.bastion_nsg.id}"

    ip_configuration {
        name                          = "${azurerm_resource_group.rg.name}-bastion-ipconfig"
        subnet_id                     = "${azurerm_subnet.subnet2.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "10.254.1.5"
        public_ip_address_id          = "${azurerm_public_ip.bastion_pip.id}"
    }
}

resource "azurerm_virtual_machine" "bastion" {
    name                  = "${azurerm_resource_group.rg.name}-bastion"
    location              = "${azurerm_resource_group.rg.location}"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    vm_size               = "${var.vm_size}"
    network_interface_ids = ["${azurerm_network_interface.bastion_nic.id}"]
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    os_profile {
        computer_name  = "${var.hostname}-bastion"
        admin_username = "${var.username}"
        admin_password = "${var.password}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${file(var.public_key_path)}"
        }
    }

    storage_image_reference {
        publisher = "${var.image_publisher}"
        offer     = "${var.image_offer}"
        sku       = "${var.image_sku}"
        version   = "${var.image_version}"
    }

    storage_os_disk {
        name              = "${var.hostname}-bastion-osdisk"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }
}