terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatestorageivan"
    container_name       = "tfstate"
    key                  = "infra/terraform.tfstate"
  }
}
