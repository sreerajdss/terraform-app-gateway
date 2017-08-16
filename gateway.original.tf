# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "yours"
  client_id       = "yours"
  client_secret   = "yours"
  tenant_id       = "yours"
} 
 
# Create a resource group
resource "azurerm_resource_group" "test" {
  name     = "gi-agwyrg0725-1"
  location = "West US"
}
# Create a virtual network in the web_servers resource group
resource "azurerm_virtual_network" "test" {
  name                = "vnet"
  resource_group_name = "${azurerm_resource_group.test.name}"
  address_space       = ["10.254.0.0/16"]
  location            = "${azurerm_resource_group.test.location}"
}
 
resource "azurerm_subnet" "test" {
  name                 = "gisubnet1"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.254.0.0/24"
}
 
resource "azurerm_subnet" "test2" {
  name                 = "gisubnet2"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.254.2.0/24"
}
 
# Create an application gateway
resource "azurerm_application_gateway" "network" {
  name                = "gi-agwy0725-1"
  location            = "West US"
  resource_group_name = "${azurerm_resource_group.test.name}"
  sku {
    name           = "Standard_Small"
    tier           = "Standard"
    capacity       = 2
  }
  gateway_ip_configuration {
      name         = "gi-agwy0725-gwip-cfg"
      subnet_id    = "${azurerm_virtual_network.test.id}/subnets/gisubnet1"
  }
  frontend_port {
      name         = "gi-agwy0725-feport"
      port         = 80
  }
  frontend_ip_configuration {
      name         = "gi-agwy0725-feip"
      subnet_id    = "${azurerm_virtual_network.test.id}/subnets/gisubnet1"     
  }
  backend_address_pool {
      name = "gi-agwy0725-beap"
  }
  backend_http_settings {
      name                  = "gi-agwy0725-be-htst"
      cookie_based_affinity = "Disabled"
     port                  = 80
      protocol              = "Http"
     request_timeout        = 1
  }
  http_listener {
    name                                  = "gi-agwy0725-httplstn"
    frontend_ip_configuration_name        = "gi-agwy0725-feip"
    frontend_port_name                    = "gi-agwy0725-feport"
    protocol                              = "Http"
  }
request_routing_rule {
      name                       = "gi-agwy0725-rqrt"
      rule_type                  = "Basic"
      http_listener_name         = "gi-agwy0725-httplstn"
      backend_address_pool_name  = "gi-agwy0725-beap"
      backend_http_settings_name = "gi-agwy0725-be-htst"
}
}
