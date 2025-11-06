output "load_balancer_ip" {
  description = "Public IP of load balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "application_url" {
  description = "URL to access application"
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "sql_server_name" {
  description = "SQL Server name"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "database_name" {
  description = "Database name"
  value       = azurerm_postgresql_flexible_server_database.webapp_db.name
}
