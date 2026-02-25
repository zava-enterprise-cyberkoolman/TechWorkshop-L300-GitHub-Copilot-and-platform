# GitHub Actions – Deployment Setup

The workflow in `.github/workflows/build-deploy.yml` uses **OIDC (Workload Identity Federation)** to authenticate to Azure — no long-lived client secrets required.

## Prerequisites

Run `azd provision` (or `azd up`) at least once so the Azure resources exist and you have the output values needed below.

## 1. Create an Azure Service Principal with Federated Credentials

```bash
az ad app create --display-name "zava-storefront-github"
# Note the appId from output

az ad sp create --id <appId>
# Note the id (object ID) from output

# Grant Contributor on the resource group and AcrPush on the registry
az role assignment create --role Contributor \
  --assignee <appId> --scope /subscriptions/<subscriptionId>/resourceGroups/<resourceGroup>

az role assignment create --role AcrPush \
  --assignee <appId> --scope /subscriptions/<subscriptionId>/resourceGroups/<resourceGroup>/providers/Microsoft.ContainerRegistry/registries/<acrName>

# Add federated credential for your repo's main branch
az ad app federated-credential create --id <appId> --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<your-org>/<your-repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

## 2. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions → Secrets** and add:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | `appId` of the service principal |
| `AZURE_TENANT_ID` | Your Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |

## 3. Configure GitHub Variables

Go to **Settings → Secrets and variables → Actions → Variables** and add:

| Variable | Example value | Where to find it |
|---|---|---|
| `AZURE_CONTAINER_REGISTRY_NAME` | `acrabc123` | ACR resource name in the portal or `azd env get-values` |
| `AZURE_CONTAINER_REGISTRY_LOGIN_SERVER` | `acrabc123.azurecr.io` | ACR → Overview → Login server |
| `AZURE_WEBAPP_NAME` | `app-dev-abc123` | App Service name in the portal or `azd env get-values` |
| `AZURE_RESOURCE_GROUP` | `rg-dev-abc123` | Resource group name in the portal or `azd env get-values` |

> **Tip:** Run `azd env get-values` to print all environment output values at once.
