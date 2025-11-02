terraform {
  required_version = ">= 1.1.0"
  backend "azurerm" {
    resource_group_name  = var.tfstate_rg
    storage_account_name = var.tfstate_sa
    container_name       = var.tfstate_container
    key                  = "${var.prefix}-terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}