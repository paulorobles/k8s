provider "azurerm" {}

resource "azurerm_resource_group" "Dummy-k8s" {
  name     = "RG-k8s-Test"
  location = "south central us"
}
