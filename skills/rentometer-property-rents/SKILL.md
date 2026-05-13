---
name: rentometer-property-rents
description: Look up the actual historical rents recorded for a specific address in Rentometer's database (not aggregate stats — the raw listings for that one property). Costs 1 premium credit. Use when the user asks "what has this exact property rented for", "rent history for [address]", or wants to verify a single property's listing record.
---

# Rentometer Property Rents

Pulls historical rental listing records for a single address. Different from `/rentometer-summary` (aggregate neighborhood stats) and `/rentometer-comps` (nearby properties) — this returns records for the exact address.

## Make the call

```bash
curl -sS "https://www.rentometer.com/api/v1/property_rents" \
  --get \
  --data-urlencode "address=$ADDRESS" \
  --data-urlencode "max_age=30" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

- `address` (required) — full address including city + state
- `max_age` (optional) — days; default 30, increase to widen the time window

The address is geocoded server-side; matches are made on the formatted address. Inexact addresses may return no matches even for a property that exists.

## Response

JSON listing the matched records with rent, date, beds, baths, source. `credits_remaining` reports premium credits left.

## When there are no matches

This is common — most properties aren't in the database. Offer the user `/rentometer-summary` instead so they get neighborhood stats for the same address.

## Errors

- `402` → out of premium credits; refill page is https://www.rentometer.com/rentometer-api/settings
- `404` → address could not be geocoded
