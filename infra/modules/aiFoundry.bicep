// Microsoft AI Foundry (Azure AI Services / Azure OpenAI) module
@description('Name of the AI Foundry hub')
param hubName string

@description('Name of the AI Foundry project')
param projectName string

@description('Azure region for the resource')
param location string

@description('Resource tags')
param tags object = {}

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string

// AI Foundry Hub (backed by Azure ML workspace with kind "Hub")
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: hubName
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'AI Foundry hub for ZavaStorefront'
    friendlyName: hubName
  }
}

// AI Foundry Project
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: projectName
  location: location
  tags: tags
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'ZavaStorefront AI Foundry project'
    friendlyName: projectName
    hubResourceId: aiHub.id
  }
}

// Azure OpenAI account for GPT-4o and Phi model deployments
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: '${hubName}-openai'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: toLower('${hubName}-openai')
    publicNetworkAccess: 'Enabled'
  }
}

// GPT-4o deployment
resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAiAccount
  name: 'gpt-4o'
  sku: {
    name: 'Standard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
  }
}

// Phi-4 deployment
resource phi3Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAiAccount
  name: 'phi-4'
  dependsOn: [gpt4Deployment] // Sequential to avoid capacity conflicts
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'Microsoft'
      name: 'Phi-4-mini-instruct'
      version: '1'
    }
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'openai-diagnostics'
  scope: openAiAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('AI Hub resource ID')
output hubId string = aiHub.id

@description('AI Project resource ID')
output projectId string = aiProject.id

@description('OpenAI endpoint')
output openAiEndpoint string = openAiAccount.properties.endpoint

@description('OpenAI account name')
output openAiAccountName string = openAiAccount.name
