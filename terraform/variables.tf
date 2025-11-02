variable "prefix" { type = string, default = "iacdemo" }
variable "location" { type = string, default = "westeurope" }
variable "admin_username" { type = string, default = "azureuser" }
variable "admin_ssh_key" { type = string }      # PUBLIC ssh key content
variable "subscription_id" { type = string }
variable "tfstate_rg" { type = string }
variable "tfstate_sa" { type = string }
variable "tfstate_container" { type = string, default = "tfstate" }
variable "web_instance_count" { type = number, default = 2 }
