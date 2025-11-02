resource "random_password" "sql_pw" {
  length  = 16
  special = true
}

resource "azurerm_mssql_server" "sql" {
  name                         = "${var.prefix}-sql"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login            = "sqladmin"
  administrator_login_password   = random_password.sql_pw.result
}

resource "azurerm_mssql_database" "appdb" {
  name      = "appdb"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"
}

output "db_fqdn" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "db_user" {
  value = azurerm_mssql_server.sql.administrator_login
}

output "db_password" {
  value     = random_password.sql_pw.result
  sensitive = true
}