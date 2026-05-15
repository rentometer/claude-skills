---
name: rentometer-atlas-facts
description: Get the full Rentometer Atlas data bundle for a bounded geographic area — rent breakdown (overall, per-bedroom, per-property-type) PLUS demographics (ACS), HUD Fair Market Rents, HUD CHAS housing affordability, BLS local unemployment, BLS QCEW industry/wages, and Census building permits. Costs 1 quickview credit. Use when the user asks about an area — metro, city, ZIP, neighborhood, school district — and wants the comprehensive view, not just rent stats. This is the killer skill for area-based investment analysis.
---

# Rentometer Atlas Facts

Returns everything Rentometer knows about a bounded geographic area in a single API call: rent stats, demographics, fair-market rents, unemployment, industry wages, and building permits. The same data backs the public `https://www.rentometer.com/average-rent-in/...` Atlas pages and is shared via a 12-hour cache, so the numbers match exactly.

**This skill is the single highest-leverage call for area-based analysis.** It replaces what most agentic real-estate tools cobble together by scraping GreatSchools, city-data, BLS, and HUD separately.

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`.

## Prerequisite: get the slug

You need an Atlas `slug`. If the user named an area in plain English ("Hyde Park Cincinnati"), call `/rentometer-atlas-search` first to resolve it. If multiple matches come back, ask the user which one — don't guess.

## Make the call

```bash
curl -sS "https://www.rentometer.com/api/v1/atlas/facts" \
  --get \
  --data-urlencode "slug=$SLUG" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

## Response shape (annotated)

```jsonc
{
  "area": {
    "slug": "hyde-park-cincinnati-oh",
    "name": "Hyde Park, Cincinnati, OH",
    "type": "neighborhood",
    "area_type": "neighborhood",
    "parent_slug": "cincinnati-oh"
  },
  "rent_breakdown": {
    "samples": 423,
    "mean": 1542.0,
    "median": 1450.0,
    "min": 650.0,
    "max": 4200.0,
    "percentile_25": 1175.0,
    "percentile_75": 1850.0,
    "bedroom_stats": {
      "0": { "min": 650,  "max": 1300, "mean": 925,  "count": 42  },
      "1": { "min": 750,  "max": 1900, "mean": 1180, "count": 168 },
      "2": { "min": 1100, "max": 2800, "mean": 1640, "count": 145 },
      "3": { "min": 1500, "max": 3600, "mean": 2200, "count": 52  }
    },
    "grouped_breakdown_stats": {
      "apartment": { "1": { "avg": 1140, "median": 1100, "min": 750, "max": 1700, "percentile_25": 950,  "percentile_75": 1300 } },
      "house":     { "3": { "avg": 2400, "median": 2350, "min": 1700,"max": 3600, "percentile_25": 2050, "percentile_75": 2750 } }
    }
  },
  "facts": {
    "acs": { /* ACS demographics — shape varies by area type */ },
    "hud_fmr": { "studio": 850, "one_br": 1025, "two_br": 1280, "three_br": 1675, "four_br": 1925 },
    "hud_chas": { /* housing-affordability indicators */ },
    "bls_laus": { "current_rate": 3.4, "current_month": "2025-12" },
    "bls_qcew": { /* industry / wage data */ },
    "census_bps": { /* permits issued, by structure type */ }
  },
  "calculated_at": "2026-05-14T08:00:00Z",
  "credits_remaining": 412,
  "token": "..."
}
```

## Flipper gating — important

Each `facts.*` source is gated behind a Flipper flag tied to the caller's account. **If the flag isn't enabled, the key is silently absent from the response — there's no "access denied" marker.** A missing `facts.bls_qcew` could mean either "no data for this area" or "this account doesn't have the flag enabled." Treat them the same: if a key is absent, the source isn't usable.

When presenting results, list only the sources that are present. Don't promise the user a section that didn't come back.

## Present to the user

A good default layout:

1. **Header**: area name, area type, sample size, `calculated_at` (note if older than a day)
2. **Rent stats table**: median, mean, 25th–75th percentile, min, max
3. **By bedroom** table: rows for each bedroom count present in `bedroom_stats`
4. **By property type & bedroom** if `grouped_breakdown_stats` has multiple types — useful for investors choosing between SFR and multifamily
5. **External data** (only sections that came back):
   - **Demographics** (`acs`): median income, median age, population, etc.
   - **Fair market rents** (`hud_fmr`): HUD's official rent ceilings
   - **Affordability** (`hud_chas`): cost-burdened renter percentages
   - **Unemployment** (`bls_laus`): current rate + month
   - **Industry & wages** (`bls_qcew`): largest employers, average wages
   - **Building permits** (`census_bps`): recent construction activity (supply pressure signal)
6. **Link** to the public Atlas page: `https://www.rentometer.com/average-rent-in/...` — derive the URL from `area.area_type` and `area.name` if needed, or just say "see the public Atlas page for this area."

## Errors

- `400 slug required` → you forgot to pass `slug`.
- `401` → API key issue; run `/rentometer-login`.
- `402` → out of quickview credits; refill at https://www.rentometer.com/rentometer-api/settings.
- `404 Unknown slug` → slug doesn't exist. Re-resolve via `/rentometer-atlas-search`.
- `422` → couldn't compute analysis (rare; area may have no listings).

## When to use this vs other skills

| Want | Use |
|---|---|
| Rent stats for an *address* | `/rentometer-summary <address>` |
| Rent stats for a *bounded area* | `/rentometer-summary` with `slug=...`, OR (more useful) `/rentometer-atlas-facts` |
| Everything we know about an area (this skill's superpower) | `/rentometer-atlas-facts` |
| Individual comp listings backing a search | `/rentometer-comps` (after a summary) |
| Precomputed aggregate stats for a metro/city/ZIP without an API key | `/rentometer-area` (mostly empty in prod today; prefer this skill) |
