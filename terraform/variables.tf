variable "project_name" {
  description = "Name of your project"
  type        = string
  default     = "mywebapp"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}

variable "db_admin_username" {
  description = "Admin username for SQL Server"
  type        = string
  default     = "sqladmin"
}

variable "db_admin_password" {
  description = "Admin password for SQL Server"
  type        = string
  sensitive   = true
}
