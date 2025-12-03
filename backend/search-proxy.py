#!/usr/bin/env python3
"""Search proxy"""
import json
import re
import logging
from aiohttp import web

# Import internal modules
from search import fetch_duckduckgo_instant, fetch_duckduckgo_html

# Set up logging 
logging.basicConfig(
    level=logging.INFO, # log level to INFO
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'  # formatting
)
logger = logging.getLogger('search-proxy')  # Create logger for this module

@web.middleware # Decorator (aiohttp) to create middleware for request/response processing
async def logging_middleware(request, handler):
    """Log all requests and responses"""
    # Log the HTTP method and request path
    logger.info(f"{request.method} {request.path}")
    try:
        # Call the next handler in the middleware chain
        response = await handler(request)
        # Log the response status code
        logger.info(f"Response: {response.status}")
        return response
    except Exception as e:
        # Log any exceptions that occur during request handling
        logger.error(f"Error: {e}")
        raise

# Function to fetch search results from API backends
async def fetch_search_results(query):
    """Route queries to web search backend"""
    # Set to lower case for easier matching
    query_lower = query.lower()
    
    # Try DuckDuckGo HTML search first
    ddg_html_results = await fetch_duckduckgo_html(query)
    if ddg_html_results:
        return ddg_html_results
    
    # Try DuckDuckGo instant answer
    ddg_instant_results = await fetch_duckduckgo_instant(query)
    if ddg_instant_results:
        return ddg_instant_results
    
    # If no results found, return default message
    return ["No relevant information found! Try rephrasing your question."]

# Handler for /context endpoint 
# (information passed back to AI model)
async def handle_context(request):
    """Handle search context requests"""
    try:
        # Parse JSON body
        data = await request.json()
        # Extract prompt
        prompt = data.get('prompt', '')
        # Fetch search results for the prompt
        results = await fetch_search_results(prompt)
        # Combine results into a single context string
        context = "\n".join(results) if results else "No search results found."
        # Return context in JSON response with CORS headers
        return web.Response(
            text=json.dumps({"context": f"Search results for '{prompt}':\n{context}"}),
            content_type='application/json',
            headers={
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        )
    # catch exceptions and return error response
    except Exception as e:
        logger.error(f"Error processing request: {e}")
        return web.Response(
            text=json.dumps({"error": f"Error processing request: {str(e)}"}),
            status=500,
            content_type='application/json'
        )

   
# Utility functions

async def healthcheck(request):
    """Health check endpoint"""
    return web.Response(text='ok')

async def root_handler(request):
    """Root URL message"""
    return web.Response(text="Search Proxy is running")
 
async def handle_options(request):
    """Handle CORS preflight requests
    
    When the browser wants to send a POST request from the frontend to the backend,
    it's making a cross-origin request (different ports).
    
    For security, the browser first sends an OPTIONS request asking permission and
    this function replies with allowed headers.
    """
    return web.Response(headers={
        'Access-Control-Allow-Origin': '*',  # Allow requests from any origin
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',  # These HTTP methods are permitted
        'Access-Control-Allow-Headers': 'Content-Type'  # These headers are allowed
    })


# Create app
app = web.Application(middlewares=[logging_middleware])
app.router.add_get('/', root_handler)
app.router.add_post('/context', handle_context)
app.router.add_get('/healthcheck', healthcheck)
app.router.add_options('/{tail:.*}', handle_options)

if __name__ == '__main__':
    # Run on all interfaces at port 8001
    web.run_app(app, host='0.0.0.0', port=8001)