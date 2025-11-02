output "lb_ip" {
  value = azurerm_public_ip.lb_ip.ip_address
}
output "db_fqdn" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}