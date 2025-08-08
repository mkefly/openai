variable "global" {
  type = object({
    location         = string
    environment      = string
    tags             = map(string)
    allowed_cidrs    = list(string)
  })
}

variable "resource_group" {
  type = object({
    name = string
  })
}

variable "openai" {
  type = object({
    account_name = string
    sku          = string
    models       = list(object({
      deployment_name = string
      model_name      = string
      model_version   = string
      tags            = map(string)
    }))
    tags = map(string)
  })
}

variable "aad" {
  type = object({
    tenant_id = string
    allowed_groups = list(object({
      name        = string
      description = string
    }))
  })
}

variable "key_vault" {
  type = object({
    name         = string
    tags         = map(string)
  })
}

variable "apim" {
  type = object({
    name            = string
    publisher_name  = string
    publisher_email = string
    sku             = string
    tags            = map(string)
  })
}

variable "identity" {
  type = object({
    name = string
    tags = map(string)
  })
}

variable "cost_management" {
  type = object({
    monthly_budget_usd  = number
    notification_emails = list(string)
    tags                = map(string)
  })
}

variable "log_analytics" {
  type = object({
    name           = string
    retention_days = number
    tags           = map(string)
  })
}
