---
name: rentometer-metrics
description: List the metrics that /rentometer-rankings can rank US areas by — each with its key, label, unit, the area types it's published for, its natural sort direction, source attribution, and whether YOUR account is entitled to it. Free — no credit charge, no state changed. Use to discover valid metric keys before calling /rentometer-rankings, to answer "what can I rank areas by?", or to explain what a metric measures and where its data comes from.
---

# Rentometer Metrics Catalog

Lists the metric vocabulary accepted by `/rentometer-rankings`, with per-caller entitlement so you never request a metric the account can't use. This is metadata — **free, no credit charge, nothing changes server-side.** Call it first whenever you're unsure of an exact metric key.

Metric keys are dotted, grouped by data family: `acs.*` (Census demographics), `hud_fmr.*` (HUD Fair Market Rents), `bls_laus.*` (local unemployment), `census_bps.*` (building permits), etc. Phase 1 covers **government-fact metrics** only; rent-based ranking isn't available yet.

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`.

## Make the call

```bash
curl -sS "https://www.rentometer.com/api/v1/atlas/metrics" \
  --get \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

No parameters. Returns the full catalog scoped to the caller's entitlements.

## Response shape (annotated)

```jsonc
{
  "metrics": [
    {
      "key": "acs.median_household_income",   // pass this to /rentometer-rankings as `metric`
      "label": "Median household income",
      "unit": "usd",                          // usd | percent | count — controls formatting
      "family": "acs",
      "default_order": "desc",                // natural "top" direction (income desc; unemployment asc)
      "area_types": ["state","metro","county","place","zcta"],  // valid `area_type` values for ranking
      "requires_flag": "atlas_show_acs_facts",
      "entitled": true,                        // false → your account can't rank by this metric

      // Self-documenting fields (present for metrics with a registered descriptor):
      "description": "Median annual household income in the area.",
      "source": "U.S. Census Bureau, American Community Survey",
      "source_url": "https://data.census.gov/table?q=B19013",
      "derivation": null,                      // non-null for computed metrics, e.g.
                                               //   acs.effective_property_tax_rate_pct: "B25090 ÷ B25082"
      "methodology_url": "https://www.census.gov/programs-surveys/acs/methodology.html"
    }
  ]
}
```

## How to use the result

- **Picking a metric for a ranking:** match the user's intent to a `key`, confirm the desired `area_type` is in that metric's `area_types`, and confirm `entitled` is `true`. Then call `/rentometer-rankings`.
- **`entitled: false`** → don't call rankings with it (you'd get a `403`). Tell the user the metric needs a data entitlement on their account and point them at https://www.rentometer.com/rentometer-api/settings.
- **Explaining a metric** ("what is this / where's it from?") → quote `description`, name the formula when `derivation` is non-null, and link `source_url` (or `methodology_url`). No second lookup needed — it's all in this payload.
- **`unit`** tells you how to format ranking values later: `usd` → `$1,234`, `percent` → `3.4%`, `count` → `1,234`.

## Present to the user

When the user asks "what can I rank by?", group the entitled metrics by `family` and list `label` + a one-line `description`. Note any metrics they asked about that came back `entitled: false`. Don't dump the raw JSON.

## Errors

- `401` → API key issue; run `/rentometer-login`.
- (No `402`/`403`/`422` here — this endpoint is free metadata and always returns the full catalog scoped to your entitlements.)

## When to use this vs other skills

| Want | Use |
|---|---|
| The list of rankable metrics + your entitlements | `/rentometer-metrics` (this skill) |
| A leaderboard of areas by a metric ("top N …") | `/rentometer-rankings` |
| Everything about one named area | `/rentometer-atlas-facts` |
| Turn a place name into a slug | `/rentometer-atlas-search` |
