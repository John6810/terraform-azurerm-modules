###############################################################
# MODULE: ApplicationGateway - Main
# Description: Azure Application Gateway v2 with WAF Policy
# Note: Public IP behind WAF is PoC only,
#       must go through Palo Alto FW in Prod
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
###############################################################
locals {
  computed_name = "agw-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
  pip_name      = "pip-${local.name}"
  waf_name      = "waf-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
}

###############################################################
# RESOURCE: WAF Policy
###############################################################
resource "azurerm_web_application_firewall_policy" "this" {
  name                = local.waf_name
  location            = var.location
  resource_group_name = var.resource_group_name

  policy_settings {
    enabled                     = true
    mode                        = var.waf_mode
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Public IP (PoC only - Prod must go through Palo)
###############################################################
resource "azurerm_public_ip" "this" {
  count = var.create_public_ip ? 1 : 0

  name                = local.pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
      Note      = "PoC only - Prod traffic must go through Palo Alto FW"
    }
  )
}

###############################################################
# RESOURCE: Application Gateway v2
###############################################################
resource "azurerm_application_gateway" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  firewall_policy_id  = azurerm_web_application_firewall_policy.this.id
  zones               = var.availability_zones

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = var.appgw_subnet_id
  }

  # Frontend - Public IP (PoC)
  dynamic "frontend_ip_configuration" {
    for_each = var.create_public_ip ? [1] : []
    content {
      name                 = "frontend-public"
      public_ip_address_id = azurerm_public_ip.this[0].id
    }
  }

  # Frontend - Private IP
  frontend_ip_configuration {
    name                          = "frontend-private"
    subnet_id                     = var.appgw_subnet_id
    private_ip_address            = var.private_ip_address
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : "Dynamic"
  }

  frontend_port {
    name = "http-80"
    port = 80
  }

  frontend_port {
    name = "https-443"
    port = 443
  }

  # Default backend (placeholder - will be configured by AGIC or manually)
  backend_address_pool {
    name = "default-backend-pool"
  }

  backend_http_settings {
    name                  = "default-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "default-http-listener"
    frontend_ip_configuration_name = "frontend-private"
    frontend_port_name             = "http-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "default-routing-rule"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "default-http-listener"
    backend_address_pool_name  = "default-backend-pool"
    backend_http_settings_name = "default-http-settings"
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      frontend_port,
      redirect_configuration,
      url_path_map,
      ssl_certificate,
    ]
  }
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_application_gateway.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}
