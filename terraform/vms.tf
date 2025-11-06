# ============================================================================
# Virtual Machine Scale Set (Web Servers)
# ============================================================================

# VM Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "web" {
  name                = "${var.project_name}-${var.environment}-vmss"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard_B1ms"
  instances           = 3
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false
  
  upgrade_mode    = "Automatic"
  health_probe_id = azurerm_lb_probe.http.id

  zones = ["1", "2", "3"]
  zone_balance = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  network_interface {
    name    = "vmss-nic"
    primary = true
    
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.main.id]
    }
  }
  
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    packages:
      - nginx
    write_files:
      - path: /var/www/html/index.html
        content: |
          <!DOCTYPE html>
          <html>
          <head><title>Azure Web App</title></head>
          <body>
            <h1>Hello from Azure!</h1>
            <p>VM managed by Terraform</p>
          </body>
          </html>
      - path: /var/www/html/health.html
        permissions: '0644'
        content: |
          OK
    runcmd:
      - systemctl start nginx
      - systemctl enable nginx
  EOF
  )
  
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT30M"
  }
}

# Auto-scaling Rules
resource "azurerm_monitor_autoscale_setting" "web" {
  name                = "${var.project_name}-${var.environment}-autoscale"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web.id
  
  profile {
    name = "AutoScale"
    
    capacity {
      default = 3
      minimum = 3
      maximum = var.autoscale_max
    }
    
    # Scale out when CPU > 75%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
      
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    
    # Scale in when CPU < 25%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
      
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }
}
