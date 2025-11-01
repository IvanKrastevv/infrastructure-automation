output "lb_ip" {
  value = azurerm_public_ip.lb_ip.ip_address
}
output "db_host" {
  value = azurerm_postgresql_flexible_server.pg.fqdn
}
