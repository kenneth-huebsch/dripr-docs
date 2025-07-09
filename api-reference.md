---
layout: page
title: API Reference
---

# Local Market Data API

The Local Market Data API provides real estate market information for specific zip codes, including pricing trends, inventory levels, and market statistics.

## Endpoint

```
GET /api/local-market-data/{zip_code}
```

## Authentication

This endpoint requires API key authentication. Contact Dripr for your API key. Include your API key in the request headers:

```
X-API-Key: your_api_key_here
```

## Request Format

### Path Parameters

| Parameter | Type   | Required | Description |
|-----------|--------|----------|-------------|
| zip_code  | string | Yes      | 5-digit US zip code |

### Example Request

```bash
curl -X GET "https://your-api-domain.com/api/local-market-data/90210" \
  -H "X-API-Key: your_api_key_here" \
  -H "Content-Type: application/json"
```

## Response Format

### Success Response (200 OK)

Returns a JSON object containing local market data comparing current market conditions with data from 3 months ago:

```json
{
    "creation_datetime": "Thu, 12 Jun 2025 00:53:57 GMT",
    "id": "b7b30e12-1336-4718-9f8e-5146d706af84",
    "new_average_days_on_market": "38.83",
    "new_average_price": "1378585",
    "new_average_price_per_sqft": "623.75",
    "new_month": "06-11-2025",
    "new_total_listings": "115",
    "old_average_days_on_market": "38.44",
    "old_average_price": "1293331",
    "old_average_price_per_sqft": "626.58",
    "old_month": "04-01-2025",
    "old_total_listings": "100",
    "zip_code": "01950"
}
```

### Response Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier for this market data record, not useful except for debugging with Dripr |
| `zip_code` | string | The 5-digit zip code for this market data |
| `creation_datetime` | string | Timestamp when this data was created/cached |
| **Current Market Data (New Fields)** |
| `new_month` | string | Date representing the current market data period |
| `new_average_price` | string | Current average home price in the zip code |
| `new_average_price_per_sqft` | string | Current average price per square foot |
| `new_average_days_on_market` | string | Current average number of days homes stay on the market |
| `new_total_listings` | string | Current total number of active listings |
| **Historical Market Data (Old Fields - 3 Months Ago)** |
| `old_month` | string | Date representing the historical market data period (3 months prior) |
| `old_average_price` | string | Average home price from 3 months ago |
| `old_average_price_per_sqft` | string | Average price per square foot from 3 months ago |
| `old_average_days_on_market` | string | Average days on market from 3 months ago |
| `old_total_listings` | string | Total number of active listings from 3 months ago |

### Data Interpretation

The API provides both current market data ("new" fields) and historical data from 3 months ago ("old" fields), allowing you to:

- **Track price trends**: Compare `new_average_price` vs `old_average_price` to see if prices are rising or falling
- **Monitor market velocity**: Compare `new_average_days_on_market` vs `old_average_days_on_market` to gauge market speed
- **Assess inventory changes**: Compare `new_total_listings` vs `old_total_listings` to understand supply trends
- **Calculate price per sqft trends**: Compare current vs historical price per square foot metrics

### Error Responses

#### 400 Bad Request
```json
{
  "error": "Invalid zip code format"
}
```

#### 401 Unauthorized
```json
{
  "error": "Missing or invalid API key"
}
```

#### 403 Unauthorized
```json
{
  "error": "Invalid or inactive API key"
}
```

#### 404 Not Found
```json
{
  "error": "No market data available for this zip code"
}
```

#### 500 Internal Server Error
```json
{
  "error": "Error getting local market data: [detailed error message]"
}
```

## Data Freshness

- The API automatically returns cached data if it's less than 30 days old
- If no fresh data exists, the API will fetch new data from external sources and cache it
- This ensures optimal performance while maintaining data accuracy

## Rate Limits

Please contact your API provider for current rate limit information.

## Example Usage

### JavaScript/Node.js

```javascript
const response = await fetch('https://your-api-domain.com/api/local-market-data/90210', {
  method: 'GET',
  headers: {
    'X-API-Key': 'your_api_key_here',
    'Content-Type': 'application/json'
  }
});

if (response.ok) {
  const marketData = await response.json();
  
  // Calculate price change percentage
  const priceChange = ((marketData.new_average_price - marketData.old_average_price) / marketData.old_average_price) * 100;
  console.log(`Price change over 3 months: ${priceChange.toFixed(2)}%`);
  
  console.log('Market data:', marketData);
} else {
  const error = await response.json();
  console.error('Error:', error.error);
}
```

### Python

```python
import requests

url = "https://your-api-domain.com/api/local-market-data/90210"
headers = {
    "X-API-Key": "your_api_key_here",
    "Content-Type": "application/json"
}

response = requests.get(url, headers=headers)

if response.status_code == 200:
    market_data = response.json()
    
    # Calculate market trends
    new_price = float(market_data['new_average_price'])
    old_price = float(market_data['old_average_price'])
    price_change_pct = ((new_price - old_price) / old_price) * 100
    
    print(f"Current average price: ${new_price:,.0f}")
    print(f"Price 3 months ago: ${old_price:,.0f}")
    print(f"Price change: {price_change_pct:.2f}%")
    
else:
    error = response.json()
    print("Error:", error["error"])
```

### cURL

```bash
# Basic request
curl -X GET "https://your-api-domain.com/api/local-market-data/90210" \
  -H "X-API-Key: your_api_key_here"

# With verbose output for debugging
curl -v -X GET "https://your-api-domain.com/api/local-market-data/90210" \
  -H "X-API-Key: your_api_key_here" \
  -H "Content-Type: application/json"
```

## Notes

- Ensure the zip code is a valid 5-digit US postal code
- The API may take longer to respond on first request for a new zip code as it fetches fresh data
- Subsequent requests for the same zip code will be faster due to caching
- All price fields are returned as strings but represent numeric values in USD
- Days on market and total listings are also returned as strings but represent numeric values
- Contact support if you need access to historical market data beyond 3 months or bulk zip code requests
