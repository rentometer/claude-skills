---
name: rentometer-summary
description: Get a Rentometer rent summary (mean/median/percentiles/sample size) for a rental address using the official Rentometer API. Costs 1 quickview credit per call. Use when the user asks for "rent comps", "what rent could this property get", "rent stats for [address]", or wants market rent for a specific bed/bath/property type.
---

# Rentometer Rent Summary

Call the Rentometer `/api/v1/summary` endpoint to get rent statistics for a property.

## What you need from the user

- **Address** OR **latitude + longitude** (exactly one — don't pass both)
- **Bedrooms** (integer 0–6, required)
- Optional: **baths** (`"1"` or `"1.5+"`), **building_type** (`apartment` or `house`), **look_back_days** (90–1460, default 365)

If the user gives a vague address ("123 Main"), ask them for city/state. Don't guess.

## Auth

Read the API key from `$RENTOMETER_API_KEY`. If unset, tell the user:

> No Rentometer API key found. Generate one at https://www.rentometer.com/rentometer-api/settings, then run `export RENTOMETER_API_KEY=<key>` (or add it to your shell profile).

## Make the call

```bash
curl -sS "https://www.rentometer.com/api/v1/summary" \
  --get \
  --data-urlencode "address=$ADDRESS" \
  --data-urlencode "bedrooms=$BEDROOMS" \
  --data-urlencode "baths=$BATHS" \
  --data-urlencode "building_type=$BUILDING_TYPE" \
  --data-urlencode "look_back_days=$LOOK_BACK_DAYS" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY" \
  -H "Accept: application/json"
```

Drop any `--data-urlencode` flags for fields the user didn't supply. For lat/lng searches, swap `address` for `latitude` and `longitude`.

Always pass `tool=claude-skills` so Rentometer can attribute usage:

```
--data-urlencode "tool=claude-skills"
```

## Interpreting the response

Key fields in the JSON:
- `mean`, `median`, `min`, `max` — rent in dollars
- `percentile_25`, `percentile_50`, `percentile_75`, `percentile_90` — rent distribution
- `samples` — number of comparable listings (anything under ~10 is thin)
- `radius_miles` — search radius used
- `quickview_url` — link to the full report on rentometer.com
- `credits_remaining` — quickview credits left in the user's wallet
- `links` — has `request pro report` and `nearby comps` URLs; the `token` field can be reused with `/rentometer-comps` to avoid re-geocoding

## Present results to the user

Format as a compact table. Always include:
- Median rent and sample size (the two numbers that matter most)
- A one-line read on confidence (e.g. "23 comps within 2 mi — solid sample")
- The `quickview_url` so they can see the visualization
- Credits remaining

## Errors

- `401 Invalid API Key` → key is wrong or expired; point user back to settings page
- `401 No Active Subscription` → user is not Pro; offer to explain pricing or fall back to area data via `/rentometer-area`
- `402 Not enough credits` → tell user to refill at https://www.rentometer.com/rentometer-api/settings
- `404 Address not found` → ask user to provide a more specific address or lat/lng
- `422 Not enough properties for analysis in that area` → suggest widening look_back_days or removing baths/building_type filters
