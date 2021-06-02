
provider "azurerm" {
	features {}
}

resource "azurerm_resource_group" "main" {
	name        = "demo2"
	location    = "westeurope"
}

resource "azurerm_iothub" "main" {
    name                  = "${azurerm_resource_group.main.name}-hub"
    resource_group_name   = azurerm_resource_group.main.name
    location              = azurerm_resource_group.main.location
    sku {
        name     = "S1"
        capacity = "1"
    }
}