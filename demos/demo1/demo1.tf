provider "azurerm" {
	features {}
}
resource "azurerm_resource_group" "example" {
	name        = "demo1"
	location    = "westeurope"
}
resource "azurerm_public_ip" "example" {
  name                = "${azurerm_resource_group.example.name}-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}