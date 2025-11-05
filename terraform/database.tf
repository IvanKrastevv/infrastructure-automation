# ============================================================================
# Azure SQL Database (MSSQL)
# ============================================================================

# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = "${var.project_name}-${var.environment}-sql"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.db_admin_username
  administrator_login_password = var.db_admin_password
  minimum_tls_version          = "1.2"
  public_network_access_enabled = false
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name      = "webapp_db"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "S0"
  
  short_term_retention_policy {
    retention_days = 7
  }
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Link DNS to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "sql-link"
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# Private Endpoint
resource "azurerm_private_endpoint" "sql" {
  name                = "${var.project_name}-${var.environment}-sql-endpoint"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.database.id
  
  private_service_connection {
    name                           = "sql-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
  
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
