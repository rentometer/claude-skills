---
name: rentometer-comps
description: Get the individual nearby comparable rental listings (with addresses, prices, beds/baths) for a property via the Rentometer API. Costs 1 premium credit per call. Use after /rentometer-summary when the user wants to see the actual comps, not just aggregate stats — e.g. "show me the comps", "what listings is this based on", "list the nearby rentals".
---

# Rentometer Nearby Comps

Call `/api/v1/nearby_comps` to get the individual comparable rental properties used in a rent analysis.

## What you need

Either a search description (same shape as `/rentometer-summary`):

- **Address** OR **latitude + longitude**
- **bedrooms** (required)
- Optional: **baths**, **building_type**

OR — preferred when you already ran a summary — a **token** from a prior `/rentometer-summary` response. Using the token reuses the existing search (no re-geocoding, same result set).

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`.

## Make the call

With a token (preferred):

```bash
curl -sS "https://www.rentometer.com/api/v1/nearby_comps" \
  --get \
  --data-urlencode "token=$TOKEN" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

Without a token, pass the same `address`/`bedrooms`/etc. params as `/rentometer-summary`.

## Response shape

- `search_address`, `search_latitude`, `search_longitude` — the anchor
- `count` — number of comps returned
- `nearby_properties` — array of comparable listings, each with address, lat/lng, price, beds, baths, building type, distance, source URL where available
- `credits_remaining` — premium credits left

## Present results

Table the comps: address, beds, baths, rent, distance. Sort by distance ascending. Call out:
- The cheapest and most expensive comp
- Any obvious outliers (more than 1.5× the median)
- Comps that look unusually distant or under-bedded vs the subject

## Errors

- `404 Invalid token provided` → token is stale; re-run `/rentometer-summary` first
- `402` → out of premium credits; refill page is https://www.rentometer.com/rentometer-api/settings
