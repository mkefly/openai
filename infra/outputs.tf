output "openai_endpoint" {
  value       = azurerm_cognitive_account.openai.endpoint
  description = "Base endpoint for the Azure OpenAI account"
}

output "apim_gateway_url" {
  value       = azurerm_api_management.main.gateway_url
  description = "Public APIM gateway URL"
}

output "allowed_group_object_ids" {
  value       = { for k, v in data.azuread_group.allowed : k => v.object_id }
  description = "Resolved AAD group object IDs"
}

output "model_deployments" {
  value = { for k, v in azurerm_cognitive_deployment.models : k => {
    name    = v.name
    model   = v.model[0].name
    version = v.model[0].version
  }}
  description = "Deployed Azure OpenAI models"
}
