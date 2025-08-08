resource "azurerm_api_management_product" "openai" {
  product_id            = "openai"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  display_name          = "Azure OpenAI"
  approval_required     = false
  published             = true
  subscription_required = false
}

resource "azurerm_api_management_named_value" "openai_endpoint" {
  name                = "OPENAI_ENDPOINT"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "OpenAI Endpoint"
  value               = azurerm_cognitive_account.openai.endpoint
}

resource "azurerm_api_management_api" "openai" {
  name                  = "openai-proxy"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "OpenAI Proxy"
  path                  = "chat"
  protocols             = ["https"]
  subscription_required = false

  import {
    content_format = "openapi+json"
    content_value  = jsonencode({
      openapi = "3.0.1"
      info = { title = "OpenAI Proxy", version = "1.0.0" }
      paths = {
        "/chat/completions" = { post = { responses = { "200" = { description = "OK" } } } }
        "/completions"      = { post = { responses = { "200" = { description = "OK" } } } }
        "/embeddings"       = { post = { responses = { "200" = { description = "OK" } } } }
      }
    })
  }
}

resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  xml_content         = <<POLICY
<policies>
  <inbound>
    <base />

    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
      <openid-config url="https://login.microsoftonline.com/${var.aad.tenant_id}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>api://${var.apim.name}</audience>
      </audiences>
      <required-claims>
        <claim name="tid"><value>${var.aad.tenant_id}</value></claim>
        <!-- If you want to pin to the SPA client: -->
        <!-- <claim name="azp"><value>${var.apim.name}-spa-client-id</value></claim> -->
        <claim name="groups">
          ${join("", [for id in keys(var.aad.allowed_groups) : "<value>" .. data.azuread_group.allowed[id].object_id .. "</value>"])}
        </claim>
      </required-claims>
    </validate-jwt>

    <!-- Rate limit -->
    <rate-limit calls="60" renewal-period="60" />

    <set-variable name="upstreamBase" value="{{OPENAI_ENDPOINT}}" />

    <!-- Managed Identity auth to AOAI -->
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />

    <!-- Keep client request path and query; AOAI expects /openai/... -->
    <rewrite-uri template="/openai@(context.Request.OriginalUrl.PathAndQuery)" />

    <set-backend-service base-url="@(context.Variables.GetValueOrDefault<string>(\"upstreamBase\"))" />
  </inbound>
  <backend>
    <base />
    <retry condition="@(context.Response == null || (int)context.Response.StatusCode >= 500)" count="2" interval="2" />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
POLICY
}

resource "azurerm_api_management_logger" "log_analytics" {
  name                  = "la"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  resource_id           = azurerm_log_analytics_workspace.main.id
  credentials {
    instrumentation_key = azurerm_log_analytics_workspace.main.primary_shared_key
  }
}

resource "azurerm_api_management_api_diagnostic" "openai" {
  identifier            = "la"
  api_management_name   = azurerm_api_management.main.name
  api_name              = azurerm_api_management_api.openai.name
  resource_group_name   = azurerm_resource_group.main.name
  sampling_percentage   = 10
  always_log_errors     = true
  http_correlation_protocol = "W3C"
  backend {
    request  { headers = ["*"]; body = true }
    response { headers = ["*"]; body = false }
  }
}
