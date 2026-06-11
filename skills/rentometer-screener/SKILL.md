---
name: rentometer-screener
description: Find US areas (metros / cities / counties / ZIPs) whose government-fact metrics ALL fall within target ranges — a multi-constraint screener. Unlike /rentometer-rankings (sort by one metric), this filters by several at once, e.g. "cities with median household income $75k–$125k, effective property tax rate below 0.75%, and median home value under $300k". Costs 1 quickview credit per call. Use when the user describes a *profile* of areas to find ("where should I look for X kind of market") rather than facts about one named place.
---

# Rentometer Area Screener

Returns the areas of one type that satisfy **every** metric constraint you give —
the "find me places that match this whole profile" query. One call replaces
enumerating candidate areas and checking each by hand.

This is the multi-filter complement to `/rentometer-rankings` (which sorts by a
single metric). Phase 1 covers **government-fact metrics** (ACS, HUD, BLS,
Census); rent-based filtering isn't available yet.

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`.

## Step 1 — pick metrics (and confirm entitlement)

Each constraint is a metric key + a `min` and/or `max`. If you don't already know
the keys, list the catalog (free): `/rentometer-metrics`. Only use metrics whose
`entitled` is `true` and that are published for your chosen `area_type` (check the
metric's `area_types`). Ranking/screening on an un-entitled metric returns `403`;
an unpublished area_type returns `422`.

## Step 2 — make the call

`filters` is a **JSON array**, each entry `{"metric": "<key>", "min": <num?>, "max": <num?>}`
(at least one of min/max per filter, max 6 filters):

```bash
curl -sS "https://www.rentometer.com/api/v1/atlas/screener" \
  --get \
  --data-urlencode "area_type=city" \
  --data-urlencode 'filters=[{"metric":"acs.median_household_income","min":75000,"max":125000},{"metric":"acs.effective_property_tax_rate_pct","max":0.75},{"metric":"acs.median_home_value","max":300000}]' \
  --data-urlencode "sort=acs.median_household_income" \
  --data-urlencode "limit=25" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

Parameters:

- `area_type` (required) — `metro`, `city` (alias `place`), `county`, `zcta`
  (alias `zip`), `neighborhood`, `school_district`, `state`. Must be in every
  filter metric's `area_types`.
- `filters` (required) — JSON array of `{metric, min?, max?}` (1–6 entries).
- `within` (optional) — parent Atlas slug to scope to (containment); resolve a
  place name to a slug with `/rentometer-atlas-search` first. Omit for
  country-wide.
- `sort` (optional) — a metric key to order results by. Defaults to the first
  filter's metric.
- `order` (optional) — `asc`/`desc`. Defaults to the sort metric's natural
  direction.
- `limit` (1–100, default 25), `offset` (paging).

## Response shape (annotated)

```jsonc
{
  "area_type": "place",
  "within": null,
  "filters": [
    { "metric": "acs.median_household_income", "label": "Median household income", "unit": "usd", "min": 75000, "max": 125000 },
    { "metric": "acs.effective_property_tax_rate_pct", "label": "Effective property tax rate", "unit": "percent", "min": null, "max": 0.75 }
  ],
  "sort": { "metric": "acs.median_household_income", "order": "desc" },
  "total_matches": 38,                 // how many areas matched ALL constraints
  "results": [
    {
      "rank": 1,
      "slug": "...",
      "display_name": "...",
      "area_type": "PlaceGeometry",
      "type": "City",
      "values": {                      // the matched value of each filter metric
        "acs.median_household_income": 118400.0,
        "acs.effective_property_tax_rate_pct": 0.61
      },
      "context": { "sample_count": 240, "record_density": 12.3 },
      "links": [
        { "rel": "facts",   "href": "https://www.rentometer.com/api/v1/atlas/facts?slug=..." },
        { "rel": "summary", "href": "https://www.rentometer.com/api/v1/summary?slug=..." }
      ]
    }
  ],
  "credits_remaining": 410,
  "generated_at": "2026-06-11T15:00:00Z"
}
```

- Each result's `values` shows **why it qualified** — format using each filter's
  `unit` (`usd` → `$118,400`, `percent` → `0.61%`, `count` → `1,234`).
- `links.facts` is the drill-down: pull the full bundle for any match with
  `/rentometer-atlas-facts`.

## Present to the user

Lead with what was screened and the count ("38 cities match all 3 criteria"). Show
a table: **area · the matched metric values** (formatted per unit). If `within` was
set, name the parent area. Offer to drill into any row via `/rentometer-atlas-facts`,
or to rank the matches by a different metric via `/rentometer-rankings`.

## Errors

- `400` → bad/empty `filters`, unknown `metric`, missing/unknown `area_type`, or a
  filter with neither min nor max.
- `401` → API key issue; run `/rentometer-login`.
- `402` → out of quickview credits; refill at https://www.rentometer.com/rentometer-api/settings.
- `403` → your account isn't entitled to a filter (or sort) metric. Don't retry.
- `404` → the `within` slug doesn't exist. Re-resolve via `/rentometer-atlas-search`.
- `422` → a metric isn't published for that `area_type` (e.g. building permits at
  ZIP level). Pick an `area_type` from the metric's `area_types`.

## When to use this vs other skills

| Want | Use |
|---|---|
| Areas matching a multi-metric *profile* ("find places where…") | `/rentometer-screener` (this skill) |
| A leaderboard by one metric ("top N by X") | `/rentometer-rankings` |
| The list of metric keys + your entitlements | `/rentometer-metrics` |
| Everything about one named area | `/rentometer-atlas-facts` |
| Turn a place name into a slug | `/rentometer-atlas-search` |
