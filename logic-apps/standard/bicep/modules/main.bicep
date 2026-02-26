param location string = resourceGroup().location
param logicAppName string
param appServicePlanName string  // Reference the existing App Service Plan ID
param AzureWebJobsStorage string
param FUNCTIONS_WORKER_RUNTIME string
param FUNCTIONS_EXTENSION_VERSION string
param APPINSIGHTS_INSTRUMENTATIONKEY string
param APPLICATIONINSIGHTS_CONNECTION_STRING string
param APP_KIND string
param AzureFunctionsJobHost__extensionBundle__id string
param AzureFunctionsJobHost__extensionBundle__version string
param WEBSITE_NODE_DEFAULT_VERSION string
param WEBSITE_VNET_ROUTE_ALL string
param logAnalyticsWorkspaceResourceGroupName string
param logAnalyticsWorkspaceName string
param tenantId string
param keyVaultName string

param appServiceEnvironment string


// Existing Appservice Environment
resource ase 'Microsoft.Web/hostingEnvironments@2021-02-01' existing = {
  name: appServiceEnvironment 
}

// Existing Appservice Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' existing = {
  name: appServicePlanName
  properties:{
    hostingEnvironmentProfile:{
      id:appServiceEnvironment.id
    }
  }	
}

// Fetch the resource ID of the existing Log Analytics Workspace dynamically
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
}

// Logic App Standard resource definition
resource logicApp 'Microsoft.Web/sites@2022-03-01' = {
  name: logicAppName
  location: location
  kind : 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id  // Reference the existing App Service Plan ID
	//hostingEnvironment: appServiceEnvironment
    state: 'Enabled'
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: FUNCTIONS_WORKER_RUNTIME  // Node.js is the default runtime for Logic Apps Standard
        }
        {
          name: 'AzureWebJobsStorage'
          value: AzureWebJobsStorage
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: FUNCTIONS_EXTENSION_VERSION
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: APPINSIGHTS_INSTRUMENTATIONKEY
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: APPLICATIONINSIGHTS_CONNECTION_STRING
        }
        {
          name: 'APP_KIND'
          value: APP_KIND
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: AzureFunctionsJobHost__extensionBundle__id
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: AzureFunctionsJobHost__extensionBundle__version
        }
        
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: WEBSITE_NODE_DEFAULT_VERSION
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: WEBSITE_VNET_ROUTE_ALL
        }       
       
      ]
      alwaysOn: true
      use32BitWorkerProcess: false
    }
  }
}
resource scmAuthPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-03-01' = {
  name: '${logicAppName}/scm'
  location: location
  properties: {
    allow: false
  }
}
resource ftpAuthPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-03-01' = {
  name: '${logicAppName}/ftp'
  location: location
  properties: {
    allow: false
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

// Access Policy for Logic App's Managed Identity to access the Key Vault secrets
resource accessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        objectId: logicApp.identity.principalId
        tenantId: tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          keys: [
            'get'   // Read key values
            'list'  // List all keys in the Key Vault
          ]
          certificates: [
            'get'   // Read certificate values
            'list'  // List all certificates in the Key Vault
          ]
        }
      }
    ]
  }
}

// Diagnostic Settings for Function App
  resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logicAppName}-logs'
  scope: logicApp
  properties: {
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}