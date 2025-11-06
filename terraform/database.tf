# ============================================================================
# Azure Database for PostgreSQL Flexible Server
# ============================================================================

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project_name}-${var.environment}-pg-flex"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16" # Changed to a modern version (e.g., 16)
  
  # Admin Credentials
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password

  sku_name               = "Standard_B1ms" # Burstable tier with 1 vCore, 2 GiB RAM
  storage_mb             = 32768           # 32 GiB in MB
  
  delegated_subnet_id    = azurerm_subnet.database.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgresql.id
  
  create_mode            = "Default"
  
  # Backup settings
  backup_retention_days  = 7 # Matches your SQL retention
#  geo_redundancy_enabled = "Disabled"
  
  # Note: PostgreSQL Flexible Server does not require a separate database resource 
  # for the initial 'postgres' database, but you can create others if needed.
}

resource "azurerm_postgresql_flexible_server_database" "webapp_db" {
  name      = "webapp_db"
  server_id = azurerm_postgresql_flexible_server.main.id
}

# ----------------------------------------------------------------------------
# Private DNS Zone for PostgreSQL Flexible Server
# ----------------------------------------------------------------------------

# Private DNS Zone - NOTE THE DIFFERENT NAME
resource "azurerm_private_dns_zone" "postgresql" {
  name                = "private.postgres.database.azure.com" # Required name for PostgreSQL Flexible Server
  resource_group_name = azurerm_resource_group.main.name
}

# Link DNS to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "pg-flex-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# ============================================================================
# Azure SQL Database (MSSQL)
# ============================================================================

# SQL Server
#resource "azurerm_mssql_server" "main" {
#  name                         = "${var.project_name}-${var.environment}-sql"
#  resource_group_name          = azurerm_resource_group.main.name
#  location                     = azurerm_resource_group.main.location
#  version                      = "12.0"
#  administrator_login          = var.db_admin_username
#  administrator_login_password = var.db_admin_password
#  minimum_tls_version          = "1.2"
#  public_network_access_enabled = false
#}

# SQL Database
#resource "azurerm_mssql_database" "main" {
#  name      = "webapp_db"
#  server_id = azurerm_mssql_server.main.id
#  sku_name  = "S0"
#  
#  short_term_retention_policy {
#    retention_days = 7
#  }
#}

# Private DNS Zone
#resource "azurerm_private_dns_zone" "sql" {
#  name                = "privatelink.database.windows.net"
#  resource_group_name = azurerm_resource_group.main.name
#}

# Link DNS to VNet
#resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
#  name                  = "sql-link"
#  private_dns_zone_name = azurerm_private_dns_zone.sql.name
#  resource_group_name   = azurerm_resource_group.main.name
#  virtual_network_id    = azurerm_virtual_network.main.id
#}

# Private Endpoint
#resource "azurerm_private_endpoint" "sql" {
#  name                = "${var.project_name}-${var.environment}-sql-endpoint"
#  location            = azurerm_resource_group.main.location
#  resource_group_name = azurerm_resource_group.main.name
#  subnet_id           = azurerm_subnet.database.id
  
#  private_service_connection {
#    name                           = "sql-connection"
#    private_connection_resource_id = azurerm_mssql_server.main.id
#    subresource_names              = ["sqlServer"]
#    is_manual_connection           = false
#  }
  
#  private_dns_zone_group {
#    name                 = "default"
#    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
#  }
#}
