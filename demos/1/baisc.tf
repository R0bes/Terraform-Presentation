provider "azurerm" {
    features {}
}
variable "name" {}
resource "azurerm_resource_group" "example" {
    name        = var.name
    location    = "westeurope"
}
resource "azurerm_public_ip" "example" {
  name                = "${var.name}-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}