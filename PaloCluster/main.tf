###############################################################
# Module PaloCluster — Palo Alto VM-Series Firewall Cluster
###############################################################
# Creates a complete cluster:
#   - Dedicated Resource Group
#   - Internal Load Balancer (trust, HA ports)
#   - Public IPs (management)
#   - VM-Series instances (3 NICs each, zonal)
#   - Backend pool associations (trust NICs -> ILB)
###############################################################

resource "time_static" "time" {}

locals {
  prefix = "${var.subscription_acronym}-${var.environment}-${var.region_code}"

  rg_name  = "rg-${local.prefix}-${var.workload}"
  ilb_name = "ilb-${local.prefix}-${var.workload}-trust"

  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# Resource Group
###############################################################
resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

###############################################################
# Internal Load Balancer — Trust (HA Ports)
###############################################################
resource "azurerm_lb" "trust" {
  name                = local.ilb_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "frontend"
    subnet_id                     = var.subnet_trust_id
    private_ip_address            = var.ilb_frontend_ip
    private_ip_address_allocation = "Static"
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "trust" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.trust.id
}

resource "azurerm_lb_probe" "trust" {
  name                = "probe-Tcp-${var.ilb_probe_port}"
  loadbalancer_id     = azurerm_lb.trust.id
  protocol            = "Tcp"
  port                = var.ilb_probe_port
  probe_threshold     = var.ilb_probe_threshold
  interval_in_seconds = var.ilb_probe_interval
}

resource "azurerm_lb_rule" "ha_ports" {
  name                           = "rule-ha-ports"
  loadbalancer_id                = azurerm_lb.trust.id
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.trust.id]
  probe_id                       = azurerm_lb_probe.trust.id
  floating_ip_enabled            = false
}

