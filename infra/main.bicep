// Root orchestration template for ZavaStorefront Azure infrastructure
// Deploys: ACR, Log Analytics + App Insights, Linux App Service, AI Foundry
// Region: westus3 | Environment: dev | Deployment: AZD + Bicep

targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('AZD environment name used to generate unique resource names')
param environmentName string

@description('Azure region for all resources')
@allowed([
  'westus3'
])
param location string = 'westus3'

@description('Full container image name (set by AZD during deploy)')
param containerImageName string = 'mcr.microsoft.com/dotnet/samples:aspnetapp'

// Tags applied to every resource
var tags = {
  'azd-env-name': environmentName
  environment: 'dev'
  project: 'zava-storefront'
}

// Unique suffix to avoid global name collisions
var resourceToken = uniqueString(subscription().id, environmentName, location)

// Resource names
var resourceGroupName     = 'rg-${environmentName}-${resourceToken}'
var acrName               = 'acr${resourceToken}'
var logAnalyticsName      = 'log-${environmentName}-${resourceToken}'
var appServicePlanName    = 'asp-${environmentName}-${resourceToken}'
var webAppName            = 'app-${environmentName}-${resourceToken}'
var aiHubName             = 'aihub-${environmentName}-${resourceToken}'
var aiProjectName         = 'aiproj-${environmentName}-${resourceToken}'

// ── Resource Group ──────────────────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ── Azure Container Registry ─────────────────────────────────────────────────
module acr './modules/acr.bicep' = {
  name: 'acr-deployment'
  scope: rg
  params: {
    name: acrName
    location: location
    tags: tags
  }
}

// ── Log Analytics + Application Insights ────────────────────────────────────
module logAnalytics './modules/logAnalytics.bicep' = {
  name: 'log-analytics-deployment'
  scope: rg
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

// ── Linux App Service (Docker, RBAC pull from ACR) ──────────────────────────
module appService './modules/appService.bicep' = {
  name: 'app-service-deployment'
  scope: rg
  params: {
    appServicePlanName: appServicePlanName
    webAppName: webAppName
    location: location
    tags: tags
    containerRegistryLoginServer: acr.outputs.loginServer
    containerRegistryId: acr.outputs.id
    containerImageName: containerImageName
    appInsightsConnectionString: logAnalytics.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: logAnalytics.outputs.appInsightsInstrumentationKey
  }
}

// ── Microsoft AI Foundry (GPT-4 + Phi in westus3) ───────────────────────────
module aiFoundry './modules/aiFoundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    hubName: aiHubName
    projectName: aiProjectName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// ── Outputs (consumed by AZD) ────────────────────────────────────────────────
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output SERVICE_WEB_NAME string = appService.outputs.webAppName
output SERVICE_WEB_URL string = appService.outputs.webAppUrl

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.name

output AZURE_AI_OPENAI_ENDPOINT string = aiFoundry.outputs.openAiEndpoint
