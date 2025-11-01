resource "azurerm_mssql_server" "db_server" {
  name                         = "my-sqlserver-demo"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladminuser"
  administrator_login_password = "P@ssw0rd1234!"
}

resource "azurerm_mssql_database" "app_db" {
  name           = "webappdb"
  server_id      = azurerm_mssql_server.db_server.id
  sku_name       = "Basic" # fits free-tier
  max_size_gb    = 1
}

output "database_connection_string" {
  value = "Server=tcp:${azurerm_mssql_server.db_server.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.app_db.name};User ID=${azurerm_mssql_server.db_server.administrator_login};Password=${azurerm_mssql_server.db_server.administrator_login_password};Encrypt=true;Connection Timeout=30;"
}
