---
name: rentometer-area
description: Get aggregate rent statistics for a US metro, city, school district, or ZIP code via Rentometer's public /api/v1/rental-data endpoints. Free / unauthenticated — no Pro subscription required. Use when the user asks about rents in a *place* rather than at a specific address — e.g. "what are average rents in Austin", "rent prices in 45208", "median rent for Cincinnati Public Schools district".
---

# Rentometer Rental Data (Public)

Look up pre-computed rent statistics for a US geographic area. This endpoint is **public** — no API key needed, free to call. Rate-limited to 100 requests/hour per IP.

## Picking the right endpoint

Four area types, each with its own path:

| User says... | Endpoint | `:id` is... |
|---|---|---|
| metro / metropolitan area | `/api/v1/rental-data/metros/:id` | metro GEOID (5-digit CBSA code, e.g. `17140` for Cincinnati) |
| city | `/api/v1/rental-data/cities/:id` | city identifier |
| school district | `/api/v1/rental-data/school-districts/:id` | district identifier |
| ZIP code | `/api/v1/rental-data/zip-codes/:id` | 5-digit ZIP, e.g. `45208` |

If the user gives a name ("Austin") rather than an ID, use `/rentometer-area-search` first to resolve it.

## Make the call

```bash
curl -sS "https://www.rentometer.com/api/v1/rental-data/zip-codes/45208" \
  -H "Accept: application/json"
```

No auth header needed. CORS is open.

## Response shape

```json
{
  "id": "zcta-45208",
  "geographic_area_type": "zcta",
  "geographic_area_id": "45208",
  "geographic_area_name": "ZIP Code 45208",
  "state_abbreviation": "OH",
  "statistics": {
    "median_rent": 1450.0,
    "average_rent": 1532.0,
    "percentile_25": 1150.0,
    "percentile_75": 1850.0,
    "min_rent": 700.0,
    "max_rent": 3500.0,
    "sample_size": 487
  },
  "data_sources": ["..."],
  "calculated_at": "2026-04-15T08:00:00Z",
  "web_url": "https://www.rentometer.com/rent-prices-zip-45208"
}
```

## Errors

- `404 insufficient_data` → area has fewer comps than the public reporting threshold; for richer data, suggest the Pro `/rentometer-summary` skill against a specific address in that area
- `404 not_found` → bad area ID; try `/rentometer-area-search`
- `429` → IP rate-limited; back off

## Present to the user

Lead with median rent, sample size, and the `web_url`. Mention `calculated_at` if the data is more than 14 days old.
