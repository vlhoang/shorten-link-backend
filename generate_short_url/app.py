import os
import logging
import azure.functions as func
from azure.cosmos import CosmosClient, exceptions
import json
import random
import string

logger = logging.getLogger("azure_func")
logger.setLevel(logging.INFO)

def generate_short_id(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        req_body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({'status': 'error', 'message': 'Invalid JSON'}),
            status_code=400,
            mimetype="application/json"
        )

    original_url = req_body.get('url')
    if not original_url:
        return func.HttpResponse(
            json.dumps({'status': 'error', 'message': 'Missing url parameter'}),
            status_code=400,
            mimetype="application/json"
        )

    short_url = generate_short_id()

    # CosmosDB connection settings from environment variables
    COSMOS_ENDPOINT = os.environ.get('COSMOS_ENDPOINT')
    COSMOS_KEY = os.environ.get('COSMOS_KEY')
    COSMOS_DB = os.environ.get('COSMOS_DB', 'UrlShortenDB')
    COSMOS_CONTAINER = os.environ.get('COSMOS_CONTAINER', 'UrlShortenContainer')

    try:
        client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
        database = client.get_database_client(COSMOS_DB)
        container = database.get_container_client(COSMOS_CONTAINER)

        # Insert the new short URL mapping
        container.create_item({
            'id': short_url,  # CosmosDB requires an 'id' field
            'short_url': short_url,
            'original_url': original_url
        })

        return func.HttpResponse(
            json.dumps({'status': 'success', 'short_url': short_url}),
            status_code=200,
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
# import random
# import string
# import json
# import logging

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# # This function receives the original URL and generates a short URL
# # Request body json need to contain attribute: "url"
# # Sample request body (JSON): 
# # {
# #   "url": "https://www.example.com"
# # }
# def lambda_handler(event, context):
#     logger.info('Event structure: ' + json.dumps(event))  # Log the event structure
    
#     body = None
#     if (event['body']) and (event['body'] is not None):
#         body = json.loads(event['body'])
#     else:
#         return {
#             'statusCode': 400,
#             'body': json.dumps({'status': 'error', 'message': 'Request body is empty'})
#         }
#     original_url = body['url']

#     short_url = ''.join(random.choices(string.ascii_letters + string.digits, k=15))

#     dynamodb = boto3.resource('dynamodb')
#     table = dynamodb.Table('UrlShortenTable')

#     try:
#         table.put_item(
#             Item={
#                 'short_url': short_url,
#                 'original_url': original_url
#             }
#         )
#         return {
#             'statusCode': 200,
#             'headers': {
#                 'Access-Control-Allow-Origin': '*',  # Allow requests from any origin
#                 'Access-Control-Allow-Headers': 'Content-Type, Authorization',  # Allow the Content-Type header
#                 'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',  # Allow OPTIONS and POST methods
#             },
#             'body': json.dumps({'short_url_code': short_url})
#         }
#     except Exception as e:
#         return {
#             'statusCode': 500,
#             'body': json.dumps({'status': 'error', 'message': str(e)})
#         }