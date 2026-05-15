---
name: rentometer-summary
description: Get a Rentometer rent summary (mean/median/percentiles/sample size) for a rental address, a lat/lng point, or a bounded Atlas area (slug) using the official Rentometer API. Costs 1 quickview credit per call. Use when the user asks for "rent comps", "what rent could this property get", "rent stats for [address]", "rent stats for [neighborhood/ZIP/city]", or wants market rent for a specific bed/bath/property type.
---

# Rentometer Rent Summary

Call the Rentometer `/api/v1/summary` endpoint to get rent statistics. Supports three input modes:

1. **Address** — geocoded street address
2. **Latitude + Longitude** — point search
3. **Slug** — bounded Atlas area (whole metro / city / ZIP / neighborhood / school district)

## What you need from the user

Pass **exactly one of**:

- `address` (full street, including city + state)
- `latitude` + `longitude`
- `slug` (Atlas slug — get from `/rentometer-atlas-search`)

Plus:

- `bedrooms` (integer 0–6) — **required for address / lat-lng searches; ignored for slug searches**
- Optional `baths` (`"1"` or `"1.5+"`), `building_type` (`apartment` or `house`), `look_back_days` (90–1460, default 365) — these are also ignored when `slug` is passed

If the user gives a vague address ("123 Main"), ask them for city/state. Don't guess. If the user names an area ("Hyde Park", "45208", "Austin"), call `/rentometer-atlas-search` first to resolve a slug — then come back here with that slug. Or, if the user wants the comprehensive area view, prefer `/rentometer-atlas-facts` over this skill.

## Auth

Resolve the API key in this order:

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If `$RENTOMETER_API_KEY` is still empty after that, tell the user to run `/rentometer-login` (don't try to walk them through it inline — that skill exists for a reason).

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

Drop any `--data-urlencode` flags for fields the user didn't supply. For lat/lng searches, swap `address` for `latitude` and `longitude`. For slug searches, swap `address` and `bedrooms` for just `slug`:

```bash
curl -sS "https://www.rentometer.com/api/v1/summary" \
  --get \
  --data-urlencode "slug=$SLUG" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

Always pass `tool=claude-skills` so Rentometer can attribute usage.

## Interpreting the response

Key fields in the JSON:
- `mean`, `median`, `min`, `max` — rent in dollars
- `percentile_25`, `percentile_50`, `percentile_75`, `percentile_90` — rent distribution
- `samples` — number of comparable listings (anything under ~10 is thin)
- `radius_miles` — search radius used (null on slug-bounded calls)
- `area` — present **only** on slug-bounded calls; an object with `slug`, `name`, `type`, `area_type` identifying which bounded geography these numbers reflect
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
