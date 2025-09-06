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
