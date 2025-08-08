locals {
  default_tags = merge(var.global.tags, { environment = var.global.environment })
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group.name
  location = var.global.location
  tags     = local.default_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  retention_in_days   = var.log_analytics.retention_days
  tags                = var.log_analytics.tags
}

resource "azurerm_key_vault" "main" {
  name                        = var.key_vault.name
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  sku_name                    = "standard"
  tenant_id                   = var.aad.tenant_id
  soft_delete_retention_days  = 30
  enable_rbac_authorization   = true
  tags                        = var.key_vault.tags
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = var.global.allowed_cidrs
  }
}

resource "azurerm_user_assigned_identity" "main" {
  name                = var.identity.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.identity.tags
}

resource "azurerm_cognitive_account" "openai" {
  name                = var.openai.account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = var.openai.sku
  identity {
    type = "UserAssigned"
    user_assigned_identities = { azurerm_user_assigned_identity.main.id = {} }
  }
  tags = var.openai.tags
}

resource "azurerm_cognitive_deployment" "models" {
  for_each            = { for m in var.openai.models : m.deployment_name => m }
  cognitive_account_id = azurerm_cognitive_account.openai.id
  name                 = each.value.deployment_name
  model {
    format   = "OpenAI"
    name     = each.value.model_name
    version  = each.value.model_version
  }
  tags = each.value.tags
}

data "azuread_group" "allowed" {
  for_each    = { for g in var.aad.allowed_groups : g.name => g }
  display_name = each.value.name
}

resource "azurerm_api_management" "main" {
  name                = var.apim.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.apim.publisher_name
  publisher_email     = var.apim.publisher_email
  sku_name            = var.apim.sku

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  tags = var.apim.tags
}

# Role assignments for MI
resource "azurerm_role_assignment" "mi_openai_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "mi_kv_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "openai-budget"
  resource_group_id = azurerm_resource_group.main.id
  amount            = var.cost_management.monthly_budget_usd
  time_grain        = "Monthly"
  dynamic "notification" {
    for_each = toset([50,80,100])
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "EqualTo"
      contact_emails = var.cost_management.notification_emails
    }
  }
  tags = var.cost_management.tags
}

resource "azurerm_monitor_diagnostic_setting" "openai_logs" {
  name                       = "diag-openai"
  target_resource_id         = azurerm_cognitive_account.openai.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  logs { category = "Audit"            enabled = true }
  logs { category = "RequestResponse"  enabled = true }
  metrics { category = "AllMetrics"    enabled = true }
}

resource "azurerm_management_lock" "openai_rg" {
  name       = "openai-rg-lock"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "Protect OpenAI RG from accidental deletion"
}
