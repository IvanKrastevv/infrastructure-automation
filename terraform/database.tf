# ============================================================================
# Azure Database for PostgreSQL Flexible Server
# ============================================================================

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project_name}-${var.environment}-pg-flex"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"

  # Admin credentials
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password

  # Basic performance tier
  sku_name   = "B_Standard_B1ms" # 1 vCore, 2 GiB RAM
  storage_mb = 32768             # 32 GiB

  # Networking
  delegated_subnet_id    = azurerm_subnet.database.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgresql.id
  public_network_access_enabled = false

  # Backup and maintenance
  backup_retention_days = 7
  create_mode           = "Default"

  lifecycle {
    # Avoids unnecessary diffs if Azure changes internal zone assignment
    ignore_changes = [
      zone,
    ]
  }
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

# Private Endpoint for PostgreSQL Flexible Server
resource "azurerm_private_endpoint" "pg_flex" {
  name                = "${var.project_name}-${var.environment}-pgflex-endpoint"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.database.id

  private_service_connection {
    name                           = "pgflex-connection"
    private_connection_resource_id = azurerm_postgresql_flexible_server.main.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pgflex-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgresql.id]
  }
}
