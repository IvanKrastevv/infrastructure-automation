terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatestorage-ivan"
    container_name       = "tfstate"
    key                  = "infra/terraform.tfstate"
  }
}
