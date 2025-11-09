#!/usr/bin/env python3
import asyncio
import json
import urllib.parse
import ssl
import re
import logging
import aiohttp
from aiohttp import web

# Set up logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('search-mcp')

# Add middleware for request logging
@web.middleware
async def logging_middleware(request, handler):
    logger.info(f"Incoming request: {request.method} {request.path}")
    if request.body_exists:
        body = await request.text()
        logger.info(f"Request body: {body}")
    try:
        response = await handler(request)
        logger.info(f"Response status: {response.status}")
        if response.body:
            logger.info(f"Response body: {response.body.decode()}")
        return response
    except Exception as e:
        logger.error(f"Error handling request: {e}")
        raise

async def fetch_weather(location):
    """Fetch weather data from OpenMeteo API with retries"""
    max_retries = 3
    retry_delay = 1  # seconds
    
    async def make_request(session, url, attempt=1):
        try:
            async with session.get(url) as response:
                if response.status == 200:
                    return await response.json()
                elif response.status == 429 and attempt < max_retries:  # Too Many Requests
                    logger.warning(f"Rate limited, retrying in {retry_delay} seconds...")
                    await asyncio.sleep(retry_delay * attempt)
                    return await make_request(session, url, attempt + 1)
                else:
                    logger.error(f"API returned status {response.status}")
                    return None
        except Exception as e:
            logger.error(f"Request error: {str(e)}")
            if attempt < max_retries:
                logger.info(f"Retrying request (attempt {attempt + 1})...")
                await asyncio.sleep(retry_delay * attempt)
                return await make_request(session, url, attempt + 1)
            return None

    try:
        logger.info(f"Fetching weather for location: {location}")
        timeout = aiohttp.ClientTimeout(total=10)  # 10 second timeout
        headers = {'User-Agent': 'OsirisSearch/1.0'}
        
        async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
            # First get coordinates for the location
            geocode_url = f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(location)}&count=1"
            logger.info(f"Geocoding URL: {geocode_url}")
            
            geo_data = await make_request(session, geocode_url)
            if not geo_data or not geo_data.get('results'):
                return ["Location not found. Please check the city name and try again."]
            
            loc = geo_data['results'][0]
            lat, lon = loc['latitude'], loc['longitude']
            logger.info(f"Found coordinates: lat={lat}, lon={lon}")
            
            # Now get weather for these coordinates
            weather_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,rain,weathercode,windspeed_10m"
            logger.info(f"Weather URL: {weather_url}")
            
            weather = await make_request(session, weather_url)
            if weather and 'current' in weather:
                current = weather['current']
                return [f"Current weather in {loc['name']}, {loc.get('country', '')}: "
                       f"Temperature: {current.get('temperature_2m', 'N/A')}°C, "
                       f"Rain: {current.get('rain', 'N/A')}mm, "
                       f"Wind Speed: {current.get('windspeed_10m', 'N/A')} km/h"]
            else:
                logger.error("Failed to get weather data")
                return ["Weather data temporarily unavailable. Please try again in a moment."]
                
    except Exception as e:
        logger.error(f"Weather error: {str(e)}")
        return ["Weather service temporarily unavailable. Please try again later."]

async def fetch_duckduckgo_instant(query):
    """Fetch instant answer from DuckDuckGo API"""
    url = "https://api.duckduckgo.com/"
    params = {
        "q": query,
        "format": "json",
        "no_html": 1,
        "skip_disambig": 1
    }
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(url, params=params, headers=headers) as response:
                if response.status == 200:
                    data = await response.json(content_type=None)
                    results = []
                    
                    if data.get('AbstractText'):
                        results.append(f"Summary: {data['AbstractText']}")
                    
                    if data.get('Definition'):
                        results.append(f"Definition: {data['Definition']}")
                    
                    if data.get('RelatedTopics'):
                        for topic in data['RelatedTopics'][:3]:
                            if isinstance(topic, dict) and topic.get('Text'):
                                results.append(f"Related: {topic['Text']}")
                    
                    if results:
                        logger.info(f"DuckDuckGo Instant Answer found {len(results)} results")
                        return results
                    
                    logger.info("DuckDuckGo Instant Answer returned nothing")
                    return []
                return []
        except Exception as e:
            logger.error(f"DuckDuckGo Instant Answer error: {str(e)}")
            return []

async def fetch_duckduckgo_html(query):
    """Scrape DuckDuckGo HTML search results"""
    from bs4 import BeautifulSoup
    
    url = "https://html.duckduckgo.com/html/"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    data = {
        'q': query
    }
    
    async with aiohttp.ClientSession() as session:
        try:
            async with session.post(url, data=data, headers=headers) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    
                    results = []
                    # Find search result divs
                    for result in soup.find_all('div', class_='result', limit=5):
                        # Get the title/link
                        title_tag = result.find('a', class_='result__a')
                        if not title_tag:
                            continue
                        title = title_tag.get_text(strip=True)
                        
                        # Get the snippet
                        snippet_tag = result.find('a', class_='result__snippet')
                        if snippet_tag:
                            snippet = snippet_tag.get_text(strip=True)
                            results.append(f"{title}: {snippet}")
                        else:
                            results.append(f"{title}")
                    
                    if results:
                        logger.info(f"DuckDuckGo HTML search found {len(results)} results")
                        return results
                    
                    logger.info("DuckDuckGo HTML search returned no results")
                    return []
                return []
        except Exception as e:
            logger.error(f"DuckDuckGo HTML search error: {str(e)}")
            return []

async def fetch_wikipedia(query):
    """Fetch results from Wikipedia API"""
    url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "format": "json",
        "list": "search",
        "srsearch": query,
        "utf8": 1
    }
    headers = {
        'User-Agent': 'OsirisSearch/1.0'
    }
    
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(url, params=params, headers=headers) as response:
                if response.status == 200:
                    data = await response.json()
                    if 'query' in data and 'search' in data['query']:
                        results = []
                        for result in data['query']['search'][:3]:
                            title = result.get('title', '')
                            snippet = result.get('snippet', '').replace('<span class="searchmatch">', '').replace('</span>', '').replace('&#039;', "'")
                            results.append(f"{title}: {snippet}")
                        return results
                    return ["No relevant information found"]
                return [f"Search failed with status: {response.status}"]
        except Exception as e:
            logger.error(f"Wikipedia error: {str(e)}")
            return [f"Search failed: {str(e)}"]

async def fetch_search_results(query):
    """Smart search router based on query content"""
    query_lower = query.lower()
    
    # Check for weather-related queries
    weather_keywords = ['weather', 'temperature', 'rain', 'forecast', 'climate']
    if any(keyword in query_lower for keyword in weather_keywords):
        # Extract location from query
        location = None
        
        # First try to find location after prepositions
        for word in ['in', 'at', 'for']:
            if f" {word} " in query_lower:
                location = query_lower.split(f" {word} ")[-1].strip()
                break
        
        # If no preposition found, try to find the last word group that's not a weather keyword
        if not location:
            words = query_lower.split()
            for i in range(len(words) - 1, -1, -1):
                if not any(keyword in words[i] for keyword in weather_keywords):
                    location = words[i]
                    break
        
        if location:
            # sanitize location: remove trailing punctuation and any weird chars
            location = re.sub(r"[^\w\s,\.-]", "", location).strip()
            logger.info(f"Extracted location from query: {location}")
            return await fetch_weather(location)
        else:
            return ["Please specify a location for the weather query (e.g., 'weather in London')"]
    
    # Try DuckDuckGo HTML search first (best for current info)
    logger.info(f"Trying DuckDuckGo HTML search for: {query}")
    ddg_html_results = await fetch_duckduckgo_html(query)
    
    if ddg_html_results:
        logger.info("Using DuckDuckGo HTML search results")
        return ddg_html_results
    
    # Try DuckDuckGo instant answer API as backup
    logger.info(f"Trying DuckDuckGo Instant Answer for: {query}")
    ddg_instant_results = await fetch_duckduckgo_instant(query)
    
    if ddg_instant_results:
        logger.info("Using DuckDuckGo Instant Answer results")
        return ddg_instant_results
    
    # Fall back to Wikipedia for encyclopedic info
    logger.info(f"DuckDuckGo had no results, trying Wikipedia for: {query}")
    wiki_results = await fetch_wikipedia(query)
    
    if wiki_results and wiki_results[0] != "No relevant information found":
        logger.info("Using Wikipedia results")
        return wiki_results
    
    return ["No relevant information found. Try rephrasing your question."]
async def handle_context(request):
    """Handle MCP context request"""
    try:
        data = await request.json()
        prompt = data.get('prompt', '')
        logger.info(f"Received context request for prompt: {prompt}")
        
        results = await fetch_search_results(prompt)
        context = "\n".join(results) if results else "No search results found."
        
        response_data = {
            "context": f"Search results for '{prompt}':\n{context}"
        }
        logger.info(f"Sending response: {response_data}")
        
        return web.Response(
            text=json.dumps(response_data),
            content_type='application/json',
            headers={
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        )
    except Exception as e:
        return web.Response(
            text=json.dumps({
                "error": f"Error processing request: {str(e)}"
            }),
            status=500,
            content_type='application/json'
        )

async def healthcheck(request):
    """Health check endpoint"""
    return web.Response(text='ok')

# Create the application
async def root_handler(request):
    return web.Response(text="MCP Server is running")

app = web.Application(middlewares=[logging_middleware])
app.router.add_get('/', root_handler)
app.router.add_post('/context', handle_context)
app.router.add_get('/healthcheck', healthcheck)

# Add CORS headers to all responses
async def handle_options(request):
    return web.Response(headers={
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    })

app.router.add_options('/{tail:.*}', handle_options)

if __name__ == '__main__':
    web.run_app(app, host='0.0.0.0', port=8001)