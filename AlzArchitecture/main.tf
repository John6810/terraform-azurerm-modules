###############################################################
# Module AlzArchitecture - ALZ Management Groups + Policies
###############################################################
# Wraps Azure/avm-ptn-alz/azurerm
# Creates: Management Group hierarchy, subscription placement,
#          policy assignments (AMBA, DDoS, Defender, Backup)
###############################################################

module "alz_architecture" {
  source             = "Azure/avm-ptn-alz/azurerm"
  version            = "0.13.0"
  architecture_name  = var.architecture_name
  parent_resource_id = var.management_root_id
  location           = var.location

  # ── Subscription Placement ──────────────────────────────────
  subscription_placement = var.subscription_placement

  # ── Hierarchy Settings ─────────────────────────────────────
  management_group_hierarchy_settings = var.management_group_hierarchy_settings

  # ── Policy Assignments Modifications ────────────────────────
  policy_assignments_to_modify = {
    "mg-lzr-${var.architecture_name}" = {
      policy_assignments = {
        Deploy-AMBA-Notification = {
          parameters = {
            ALZAlertSeverity = jsonencode({ value = var.alert_severity })
          }
        }
        Deploy-MDFC-Config-H224 = {
          parameters = {
            emailSecurityContact = jsonencode({ value = var.email_security_contact })
            # Defender plans — activated everywhere under mg-lzr. Most plans
            # are pay-per-use on actual resources: zero resources ≈ zero
            # cost, but coverage is automatic as soon as a workload of that
            # type arrives. Cleaner than maintaining exemptions + missing
            # coverage on first deployment.
            enableAscForApis        = jsonencode({ value = var.defender_plans.apis })
            enableAscForAppServices = jsonencode({ value = var.defender_plans.app_services })
            enableAscForArm         = jsonencode({ value = var.defender_plans.arm })
            enableAscForContainers  = jsonencode({ value = var.defender_plans.containers })
            enableAscForCosmosDbs   = jsonencode({ value = var.defender_plans.cosmos_dbs })
            enableAscForCspm        = jsonencode({ value = var.defender_plans.cspm })
            enableAscForKeyVault    = jsonencode({ value = var.defender_plans.key_vault })
            enableAscForOssDb       = jsonencode({ value = var.defender_plans.oss_db })
            enableAscForServers     = jsonencode({ value = var.defender_plans.servers })
            enableAscForSql         = jsonencode({ value = var.defender_plans.sql })
            enableAscForSqlOnVm     = jsonencode({ value = var.defender_plans.sql_on_vm })
            enableAscForStorage     = jsonencode({ value = var.defender_plans.storage })
          }
        }
      }
    }
    "mg-plat-${var.architecture_name}" = {
      policy_assignments = {
        Enable-DDoS-VNET = {
          parameters = {
            ddosPlan = jsonencode({ value = var.ddos_protection_plan_id })
          }
        }
      }
    }
    "mg-idt-${var.architecture_name}" = {
      policy_assignments = {
        Deploy-VM-Backup = {
          parameters = {
            exclusionTagValue = jsonencode({ value = var.backup_exclusion_tags })
          }
        }
      }
    }
  }

  # ── Policy Default Values ───────────────────────────────────
  policy_default_values = {
    amba_alz_management_subscription_id            = jsonencode({ value = var.management_subscription_id })
    amba_alz_resource_group_location               = jsonencode({ value = var.location })
    amba_alz_resource_group_name                   = jsonencode({ value = var.amba_resource_group_name })
    amba_alz_resource_group_tags                   = jsonencode({ value = var.amba_resource_group_tags })
    amba_alz_byo_user_assigned_managed_identity_id = jsonencode({ value = var.ama_identity_id })
    amba_alz_disable_tag_name                      = jsonencode({ value = var.amba_disable_tag_name })
    amba_alz_disable_tag_values                    = jsonencode({ value = var.amba_disable_tag_values })
    amba_alz_action_group_email                    = jsonencode({ value = var.action_group_email })
    amba_alz_byo_action_group                      = jsonencode({ value = var.action_group_ids })
    log_analytics_workspace_id                     = jsonencode({ value = var.log_analytics_workspace_id })
    private_dns_zone_subscription_id               = jsonencode({ value = var.connectivity_subscription_id })
    private_dns_zone_region                        = jsonencode({ value = var.location })
    private_dns_zone_resource_group_name           = jsonencode({ value = var.private_dns_zone_resource_group_name })
  }
}
