import os
import logging
import azure.functions as func
from azure.cosmos import CosmosClient, exceptions
import json

logger = logging.getLogger("azure_func")
logger.setLevel(logging.INFO)

# Azure Function HTTP trigger for redirecting short URLs
def main(req: func.HttpRequest) -> func.HttpResponse:
    short_url = req.route_params.get('short_url')
    if not short_url:
        return func.HttpResponse(
            json.dumps({'status': 'error', 'message': 'Missing short_url parameter'}),
            status_code=400,
            mimetype="application/json"
        )

    # CosmosDB connection settings from environment variables
    COSMOS_ENDPOINT = os.environ.get('COSMOS_ENDPOINT')
    COSMOS_KEY = os.environ.get('COSMOS_KEY')
    COSMOS_DB = os.environ.get('COSMOS_DB', 'UrlShortenDB')
    COSMOS_CONTAINER = os.environ.get('COSMOS_CONTAINER', 'UrlShortenContainer')

    try:
        client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
        database = client.get_database_client(COSMOS_DB)
        container = database.get_container_client(COSMOS_CONTAINER)

        # Query for the short_url
        query = "SELECT * FROM c WHERE c.short_url = @short_url"
        items = list(container.query_items(
            query=query,
            parameters=[{"name": "@short_url", "value": short_url}],
            enable_cross_partition_query=True
        ))

        if items:
            original_url = items[0].get('original_url')
            return func.HttpResponse(
                json.dumps({'status': 'redirecting', 'url': original_url}),
                status_code=308,
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                    'Location': original_url
                },
                mimetype="application/json"
            )
        else:
            return func.HttpResponse(
                json.dumps({'status': 'error', 'message': 'URL not found'}),
                status_code=404,
                mimetype="application/json"
            )
    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"CosmosDB error: {str(e)}")
        return func.HttpResponse(
            json.dumps({'status': 'error', 'message': 'Database error'}),
            status_code=500,
            mimetype="application/json"
        )


# import boto3
# import json
# import logging

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# # This function will get original URL from shorten URL then return to the user
# def lambda_handler(event, context):
#     logger.info('Event structure: ' + json.dumps(event))  # Log the event structure

#     short_url = event['pathParameters']['short_url']

#     dynamodb = boto3.resource('dynamodb')
#     table = dynamodb.Table('UrlShortenTable')

#     response = table.get_item(
#         Key={
#             'short_url': short_url
#         }
#     )

#     if 'Item' in response:
#         return {
#             'statusCode': 308,
#             'headers': {
#                 'Access-Control-Allow-Origin': '*',  # Allow requests from any origin
#                 'Access-Control-Allow-Headers': 'Content-Type, Authorization',  # Allow the Content-Type header
#                 'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',  # Allow OPTIONS and POST methods
#                 'Location': response['Item']['original_url']
#             },
#             'body': json.dumps({'status': 'redirecting', 'url': response['Item']['original_url']})
#         }
#     else:
#         return {
#             'statusCode': 404,
#             'body': json.dumps({'status': 'error', 'message': 'URL not found'})
#         }
