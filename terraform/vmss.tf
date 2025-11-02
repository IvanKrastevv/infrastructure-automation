# Public IP
resource "azurerm_public_ip" "lb_ip" {
  name                = "${var.prefix}-lb-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Load Balancer
resource "azurerm_lb" "lb" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicFrontend"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
}

# Backend pool
resource "azurerm_lb_backend_address_pool" "backendpool" {
  name                = "backendpool"
  loadbalancer_id     = azurerm_lb.lb.id
  resource_group_name = azurerm_resource_group.rg.name
}

# Health probe
resource "azurerm_lb_probe" "http_probe" {
  name                = "http-probe"
  protocol            = "Http"
  port                = 80
  request_path        = "/healthz"
  loadbalancer_id     = azurerm_lb.lb.id
  resource_group_name = azurerm_resource_group.rg.name
}

# LB rule
resource "azurerm_lb_rule" "http_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  resource_group_name            = azurerm_resource_group.rg.name
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicFrontend"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backendpool.id
  probe_id                       = azurerm_lb_probe.http_probe.id
}

# VM Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "${var.prefix}-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B1ls"
  instances           = 2
  admin_username      = var.admin_username

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_key
  }

  network_interface {
    name    = "nic"
    primary = true
    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backendpool.id]
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  custom_data = filebase64("${path.module}/scripts/cloud-init.sh")
}
