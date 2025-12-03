"""Wikipedia API integration"""
import logging
import aiohttp

logger = logging.getLogger('search-proxy')

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
                            snippet = result.get('snippet', '')
                            # Clean up HTML entities
                            snippet = snippet.replace('<span class="searchmatch">', '')
                            snippet = snippet.replace('</span>', '')
                            snippet = snippet.replace('&#039;', "'")
                            results.append(f"{title}: {snippet}")
                        return results
                    return ["No relevant information found"]
                return [f"Search failed with status: {response.status}"]
        except Exception as e:
            logger.error(f"Wikipedia error: {str(e)}")
            return [f"Search failed: {str(e)}"]
