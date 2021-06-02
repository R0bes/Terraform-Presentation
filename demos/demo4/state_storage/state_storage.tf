provider "azurerm" {
	features { }
}

resource "azurerm_resource_group" "state_storage" {
  name     = "demo4_state-storage"
  location = "westeurope"
}

resource "azurerm_storage_account" "state_storage" {
	name                     = "demo4account"
    resource_group_name      = azurerm_resource_group.state_storage.name
	location                 = azurerm_resource_group.state_storage.location
	account_tier             = "Standard"
	account_replication_type = "LRS"
}

resource "azurerm_storage_container" "state_storage" {
	name                    = "demo4container"
	storage_account_name	= azurerm_storage_account.state_storage.name
	container_access_type	= "private"
}

