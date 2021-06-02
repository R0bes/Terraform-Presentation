
terraform {
	backend "azurerm" {
        resource_group_name  = "demo4_state-storage"
        storage_account_name = "demo4account"
        container_name       = "demo4container"
        key                  = "demo4.tfstate"
    }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
	name        = "demo4"
	location    = "westeurope"
}
resource "azurerm_public_ip" "example" {
  name                = "${azurerm_resource_group.example.name}-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}