terraform {
  backend "azurerm" {
    resource_group_name  = "<state-rg>"
    storage_account_name = "<state-sa>"
    container_name       = "tfstate"
    key                  = "openai-enterprise-platform/${var.global.environment}.tfstate"
  }
}
