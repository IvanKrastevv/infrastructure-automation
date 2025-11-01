variable "subscription_id" { type = string }
variable "prefix" { type = string, default = "sslchecker" }
variable "location" { type = string, default = "westeurope" }
variable "admin_username" { type = string, default = "azureuser" }
variable "admin_ssh_key" { type = string }
# Backend info
variable "tfstate_rg" { type = string }
variable "tfstate_sa" { type = string }
variable "tfstate_container" { type = string, default = "tfstate" }
