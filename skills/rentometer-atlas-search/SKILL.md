---
name: rentometer-atlas-search
description: Resolve a US place name to a Rentometer Atlas slug (used by /rentometer-atlas-facts and the slug variant of /rentometer-summary). Free — no credit charge. Use when the user names a metro, city, ZIP, neighborhood, school district, or county (e.g. "Hyde Park Cincinnati", "Austin TX", "45208") and you need the canonical slug for follow-up calls.
---

# Rentometer Atlas Search

Fuzzy-search the Atlas geographic catalog by name. Returns one or more matches with their canonical slug, friendly name, and area type. The matched `slug` is the input to `/rentometer-atlas-facts` and the slug variant of `/rentometer-summary`.

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`. The endpoint is API-key-protected (for per-key rate limiting) but charges no credits.

## Make the call

```bash
curl -sS "https://www.rentometer.com/api/v1/atlas/search" \
  --get \
  --data-urlencode "q=$QUERY" \
  --data-urlencode "limit=15" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

- `q` (required, min 2 chars) — query string
- `limit` (optional, 1–50, default 15)

Queries shorter than 2 characters return an empty `results` array (HTTP 200, not an error).

## Response shape

```json
{
  "results": [
    {
      "slug": "hyde-park-cincinnati-oh",
      "name": "Hyde Park, Cincinnati, OH",
      "type": "neighborhood",
      "area_type": "neighborhood",
      "total_count": 423,
      "land_area_sq_mi": 2.6,
      "record_density": 162.7
    }
  ]
}
```

`area_type` is one of: `metro`, `city`, `zcta`, `neighborhood`, `school_district`, `county`, `state`. Results are ordered by relevance, listing density, and total listing count — the first match is usually the best.

## Present to the user

If there's one obvious match, name it and proceed (offer to call `/rentometer-atlas-facts` or `/rentometer-summary` with the slug). If there are multiple plausible matches, list them as a table with `name`, `area_type`, and `total_count` so the user can pick — don't auto-select.

## Errors

- `401` → API key invalid; tell user to run `/rentometer-login`.
- `429` → rate-limited. Back off; run `/rentometer-quota` to see the window.
- Empty `results` → narrow or rephrase the query.
