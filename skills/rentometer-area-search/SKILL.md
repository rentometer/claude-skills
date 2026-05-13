---
name: rentometer-area-search
description: Search Rentometer's geographic area catalog by name to find the ID needed for /rentometer-area. Free / unauthenticated. Use when the user names a place ("Austin", "Cincinnati Public Schools") but you don't have its area ID yet.
---

# Rentometer Area Search

Resolve a place name to a geographic area ID that `/rentometer-area` can look up.

## Make the call

```bash
curl -sS "https://www.rentometer.com/api/v1/rental-data/search" \
  --get \
  --data-urlencode "q=$QUERY" \
  --data-urlencode "type=$TYPE" \
  --data-urlencode "state=$STATE" \
  --data-urlencode "limit=10"
```

- `q` (required) — search query, e.g. "Austin"
- `type` (optional) — one of `metro`, `city`, `school_district`, `zcta`
- `state` (optional) — 2-letter state abbreviation, e.g. `TX`. Helps disambiguate ("Springfield").
- `limit` (optional) — 1–50, default 10

No auth needed.

## Response

```json
{
  "results": [
    {
      "id": "metro-12420",
      "geographic_area_type": "metro",
      "geographic_area_name": "Austin-Round Rock, TX",
      "state_abbreviation": "TX",
      "statistics": {...},
      ...
    }
  ],
  "total_count": 1,
  "query": "Austin"
}
```

## Next step

Pass the matched area's `geographic_area_id` (and area type) to `/rentometer-area` to get the full stats. If multiple results come back, show the user the list and ask which one they meant — don't auto-pick.
