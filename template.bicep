param location string = resourceGroup().location
param functionAppName string = 'shortenlinkfunc${uniqueString(resourceGroup().id)}'
param storageAccountName string = 'shortenlinksa${uniqueString(resourceGroup().id)}'
param cosmosDbAccountName string = 'shortenlinkcosmos${uniqueString(resourceGroup().id)}'
param apiManagementName string = 'shortenlinkapim${uniqueString(resourceGroup().id)}'
param cosmosDbDatabaseName string = 'UrlShortenDB'
param cosmosDbContainerName string = 'UrlShortenContainer'
param apiName string = 'shortenlinkapi'
param apiDisplayName string = 'Shorten Link API'
param apiPath string = 'api'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    dnsEndpointType: 'Standard'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
  }
  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {}
    }
    resource deploymentContainer 'containers' = {
      name: 'deployment'
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'shortenlinkplan'
  location: location
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}


resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
    }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}deployment'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 512
      }
      runtime: { 
        name: 'python'
        version: '3.12'
      }
    }
  }
  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: {
        AzureWebJobsStorage__accountName: storageAccount.name
        COSMOS_ENDPOINT: cosmosDbAccount.properties.documentEndpoint
        COSMOS_KEY: listKeys(cosmosDbAccount.id, cosmosDbAccount.apiVersion).primaryMasterKey
        COSMOS_DB: cosmosDbDatabaseName
        COSMOS_CONTAINER: cosmosDbContainerName
      }
  }
}

// Role Assignment for Blob Data Contributor
resource blobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, 'storage-contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    )
    principalId: functionApp.identity.principalId
  }
}

var functionAppHostname = '${functionApp.name}.azurewebsites.net'

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  name: '${cosmosDbAccount.name}/${cosmosDbDatabaseName}'
  properties: {
    resource: {
      id: cosmosDbDatabaseName
    }
  }
}

resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  name: '${cosmosDbAccount.name}/${cosmosDbDatabaseName}/${cosmosDbContainerName}'
  properties: {
    resource: {
      id: cosmosDbContainerName
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
    }
  }
}

resource apiManagement 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apiManagementName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'admin@example.com'
    publisherName: 'ShortenLink'
  }
}

// Add to your main.bicep after APIM resource



resource apimApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: '${apiManagement.name}/${apiName}'
  properties: {
    displayName: apiDisplayName
    path: apiPath
    protocols: [
      'https'
    ]
    apiRevision: '1'
    serviceUrl: 'https://${functionAppHostname}/api'
    // format: 'swagger-link-json'
    // value: 'https://${functionAppHostname}/api/swagger.json' // If you have OpenAPI spec published
  }
  dependsOn: [
    apiManagement
    functionApp
  ]
}

// Operation: POST /generate-short-url
resource apimApiGenerateShortUrl 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  name: '${apiManagement.name}/${apiName}/generate-short-url'
  properties: {
    displayName: 'Generate Short URL'
    method: 'POST'
    urlTemplate: '/generate-short-url'
    request: {
      queryParameters: []
      headers: []
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Short URL generated'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
    policies: '''
      <policies>
        <inbound>
          <base />
          <set-backend-service base-url="https://${functionAppHostname}/api/generate-short-url" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
        </outbound>
      </policies>
    '''
  }
  dependsOn: [
    apimApi
  ]
}

// Operation: GET /link/{short_url}
resource apimApiGetUrl 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  name: '${apiManagement.name}/${apiName}/get-url'
  properties: {
    displayName: 'Get Original URL'
    method: 'GET'
    urlTemplate: '/link/{short_url}'
    templateParameters: [
      {
        name: 'short_url'
        required: true
        type: 'string'
        description: 'The short URL code'
      }
    ]
    request: {
      queryParameters: []
      headers: []
    }
    responses: [
      {
        statusCode: 308
        description: 'Redirect to original URL'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
      {
        statusCode: 404
        description: 'URL not found'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
    policies: '''
      <policies>
        <inbound>
          <base />
          <set-backend-service base-url="https://${functionAppHostname}/api/link/{short_url}" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
        </outbound>
      </policies>
    '''
  }
  dependsOn: [
    apimApi
  ]
}
