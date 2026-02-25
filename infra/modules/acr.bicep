// Azure Container Registry module
@description('Name of the Container Registry')
param name string

@description('Azure region for the resource')
param location string

@description('Resource tags')
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false // Use RBAC, not admin credentials
  }
}

@description('ACR login server URL')
output loginServer string = acr.properties.loginServer

@description('ACR resource ID')
output id string = acr.id

@description('ACR name')
output name string = acr.name
