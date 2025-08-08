# Infra (Terraform)

## What this deploys
- Resource Group, Log Analytics
- Key Vault (RBAC, firewall deny by default)
- User-Assigned Managed Identity (MI)
- Azure OpenAI account + model deployments
- API Management (APIM) with MI, named values, product
- APIM policy: AAD JWT validation (groups), rate limit, retries, MI auth to AOAI
- Budget with 50/80/100% notifications
- Diagnostics for AOAI and APIM
- Delete lock at RG scope

## Usage
1. Create remote state, then copy `backend.example.tf` to `backend.tf` and fill values.
2. Create `terraform.tfvars` (see variables).
3. `terraform init && terraform plan && terraform apply`.
4. Upload any required KV secrets out-of-band (if you use key auth).

## Notes
- Prefer **Managed Identity** to access Azure OpenAI.
- For private networking, add Private Endpoints + Private DNS (not included here).
