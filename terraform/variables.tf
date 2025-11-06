variable "project_name" {
  description = "Name of your project"
  type        = string
  default     = "ivan"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "test-project"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australia east"
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

variable "autoscale_max" {
  type        = number
  default     = 10
  description = "Maximum number of VM instances in scale set"
}
