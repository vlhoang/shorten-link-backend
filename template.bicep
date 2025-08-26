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
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'shortenlinkplan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'COSMOS_ENDPOINT'
          value: cosmosDbAccount.properties.documentEndpoint
        }
        {
          name: 'COSMOS_KEY'
          value: listKeys(cosmosDbAccount.id, cosmosDbAccount.apiVersion).primaryMasterKey
        }
        {
          name: 'COSMOS_DB'
          value: cosmosDbDatabaseName
        }
        {
          name: 'COSMOS_CONTAINER'
          value: cosmosDbContainerName
        }
      ]
    }
    httpsOnly: true
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
    serviceUrl: 'https://${functionAppHostname}'
    format: 'swagger-link-json'
    value: 'https://${functionAppHostname}/api/swagger.json' // If you have OpenAPI spec published
  }
  dependsOn: [
    apiManagement
    functionApp
  ]
}

// Operation: POST /generate-short-url
resource apimApiGenerateShortUrl 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  name: '${apiManagement.name}/${apimApi.name}/generate-short-url'
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
  name: '${apiManagement.name}/${apimApi.name}/get-url'
  properties: {
    displayName: 'Get Original URL'
    method: 'GET'
    urlTemplate: '/link/{short_url}'
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
