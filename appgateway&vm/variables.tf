variable "subscription_id" {
	description = "The subscription to create the deployment with."
    default     = "ad3e11b5-0d6e-4121-b62f-3649cb63dfd5"
}

variable "client_id" {
	description = "The client ID of the service account (principal)."
    default     = "b1ff48d9-0f3b-4908-af3f-bc01ddc78bc3"
}

variable "client_secret" {
	description = "The client secret of the service account (principal)."
    default     = "~w1AgAH3.f0fEzEl-S0Jiw9nso~xCoMYC8"
}

variable "tenant_id" {
	description = "The ID of the Azure Active Directory Tenant."
    default     = "0173c9bb-83c7-4189-836d-b22c31b3a93e"
}

variable "resource_group" {
	description = "The name of the resource group in which to create the virtual network."
    default     = "TerraformIacIaas"
}

variable "hostname" {
	description = "VM name referenced also in storage-related names."
    default     = "TerraformIacIaas"
}

variable "dns_name" {
	description = " Label for the Domain Name. Will be used to make up the FQDN. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system."
    default     = "TerraformIacIaas"
}

variable "location" {
	description = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
	default     = "westeurope"
}

variable "virtual_network_name" {
	description = "The name for the virtual network."
	default     = "vnetprasad"
}

variable "vm_size" {
	description = "Specifies the size of the virtual machine."
	default     = "Standard_A0"
}

variable "image_publisher" {
	description = "name of the publisher of the image (az vm image list)"
	default     = "Canonical"
}

variable "image_offer" {
	description = "the name of the offer (az vm image list)"
	default     = "UbuntuServer"
}

variable "image_sku" {
	description = "image sku to apply (az vm image list)"
	default     = "16.04-LTS"
}

variable "image_version" {
	description = "version of the image to apply (az vm image list)"
	default     = "latest"
}

variable "username" {
	description = "administrator user name"
	default     = "ubuntu"
}

variable "password" {
	description = "administrator password (recommended to disable password auth)"
	default		= "C0c0nut1234!"
}

variable "private_key_path" {
	description = "Path to the private ssh key used to connect to the machine within the gateway."
	default = "/home/ubuntu/.ssh/id_rsa"
}

variable "public_key_path" {
	description = "Path to your SSH Public Key"
	default = "/home/ubuntu/.ssh/id_rsa.pub"
}