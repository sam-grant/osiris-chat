"""DuckDuckGo search"""
import logging
import aiohttp
from bs4 import BeautifulSoup

logger = logging.getLogger('search-proxy')

async def fetch_duckduckgo_instant(query):
    """Fetch instant answer from DuckDuckGo API"""
    # Set up request parameters and headers
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
    
    # Asynchronous HTTP session
    async with aiohttp.ClientSession() as session:
        try: # Make GET request to DuckDuckGo API
            async with session.get(url, params=params, headers=headers) as response:
                if response.status == 200: # Success code
                    # Parse JSON response
                    data = await response.json(content_type=None)
                    # Extract info
                    # Check for AbstractText, Definition, RelatedTopics
                    # Append to results list
                    results = []

                    if data.get('AbstractText'):
                        results.append(f"Summary: {data['AbstractText']}")

                    if data.get('Definition'):
                        results.append(f"Definition: {data['Definition']}")
                    
                    if data.get('RelatedTopics'):
                        for topic in data['RelatedTopics'][:3]:
                            if isinstance(topic, dict) and topic.get('Text'):
                                results.append(f"Related: {topic['Text']}")
                    
                    if results: # Return results if found
                        logger.info(f"DuckDuckGo Instant Answer found {len(results)} results")
                        return results
                    
                    logger.info("DuckDuckGo Instant Answer returned nothing")
                    return []
                return []
        # Catch and log exceptions
        except Exception as e:
            logger.error(f"DuckDuckGo Instant Answer error: {str(e)}")
            return []

async def fetch_duckduckgo_html(query):
    """Scrape DuckDuckGo HTML search results
    Get top 5 results with title and snippet
    """
    # Set up request parameters and headers
    url = "https://html.duckduckgo.com/html/"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    data = {'q': query}
    
    # Asynchronous HTTP session
    async with aiohttp.ClientSession() as session:
        try: # Make POST request to DuckDuckGo HTML search API
            async with session.post(url, data=data, headers=headers) as response:
                if response.status == 200: # Success code
                    # Parse HTML response with BeautifulSoup
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')

                    # Extract top 5 results with title and snippet
                    # Append to results list
                    results = []

                    # Loop through result divs
                    for result in soup.find_all('div', class_='result', limit=5):
                        # Extract title 
                        title_tag = result.find('a', class_='result__a')
                        if not title_tag: # Skip if no title
                            continue
                        title = title_tag.get_text(strip=True)

                        # Extract snippet
                        snippet_tag = result.find('a', class_='result__snippet')
                        if snippet_tag: # If snippet exists
                            snippet = snippet_tag.get_text(strip=True)
                            results.append(f"{title}: {snippet}")
                        else: # Just return title
                            results.append(f"{title}")

                    # Return results if found
                    if results:
                        logger.info(f"DuckDuckGo HTML search found {len(results)} results")
                        return results
                    
                    logger.info("DuckDuckGo HTML search returned no results")
                    return []
                return []
            
        # Catch and log exceptions
        except Exception as e:
            logger.error(f"DuckDuckGo HTML search error: {str(e)}")
            return []
