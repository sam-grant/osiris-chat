"""Weather API integration using OpenMeteo"""
import asyncio
import urllib.parse
import logging
import aiohttp

logger = logging.getLogger('search-proxy')


async def fetch_weather(location):
    """Fetch weather data from OpenMeteo API with retries"""
    max_retries = 3
    retry_delay = 1

    async def make_request(session, url, attempt=1):
        try:
            async with session.get(url) as response:
                if response.status == 200:
                    return await response.json()
                elif response.status == 429 and attempt < max_retries:
                    logger.warning(f"Rate limited, retrying in {retry_delay} seconds...")
                    await asyncio.sleep(retry_delay * attempt)
                    return await make_request(session, url, attempt + 1)
                else:
                    logger.error(f"API returned status {response.status}")
                    return None
        except Exception as e:
            logger.error(f"Request error: {str(e)}")
            if attempt < max_retries:
                await asyncio.sleep(retry_delay * attempt)
                return await make_request(session, url, attempt + 1)
            return None

    try:
        logger.info(f"Fetching weather for location: {location}")
        timeout = aiohttp.ClientTimeout(total=10)
        headers = {'User-Agent': 'OsirisSearch/1.0'}

        async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
            # Get coordinates for the location
            geocode_url = f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(location)}&count=1"

            geo_data = await make_request(session, geocode_url)
            if not geo_data or not geo_data.get('results'):
                return ["Location not found. Please check the city name and try again."]

            loc = geo_data['results'][0]
            lat, lon = loc['latitude'], loc['longitude']

            # Get weather for these coordinates
            weather_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,rain,weathercode,windspeed_10m"

            weather = await make_request(session, weather_url)
            if weather and 'current' in weather:
                current = weather['current']
                return [f"Current weather in {loc['name']}, {loc.get('country', '')}: "
                       f"Temperature: {current.get('temperature_2m', 'N/A')}°C, "
                       f"Rain: {current.get('rain', 'N/A')}mm, "
                       f"Wind Speed: {current.get('windspeed_10m', 'N/A')} km/h"]
            else:
                return ["Weather data temporarily unavailable. Please try again in a moment."]

    except Exception as e:
        logger.error(f"Weather error: {str(e)}")
        return ["Weather service temporarily unavailable. Please try again later."]