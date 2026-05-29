---
name: rentometer-rankings
description: Rank US areas by a metric — "top N cities/metros/counties/ZIPs/neighborhoods by X" — optionally scoped to a parent area. X is a government data point Rentometer already curates per area (median household income, fair-market rent, unemployment, building permits, cost burden, etc.). Costs 1 quickview credit per call (one call replaces dozens of per-area lookups). Use when the user wants a leaderboard or "best/highest/lowest" list rather than facts about one named place — e.g. "top 10 metros by median income", "the 5 lowest-unemployment counties in Ohio", "highest-rent ZIPs in the Boston metro". Call /rentometer-metrics first if you're unsure which metric keys exist.
---

# Rentometer Rankings

Returns a sorted list of areas ranked by a single metric, instead of facts about
one place. This is the call to reach for when the user asks for a **leaderboard**
("top / best / highest / lowest N …") rather than "tell me about <place>".

One ranking call replaces enumerating candidate areas and calling
`/rentometer-atlas-facts` once each — so it's both cheaper (flat 1 quickview
credit) and far fewer round-trips.

> Phase 1 covers **government-fact metrics** (ACS, HUD, BLS, Census). Rent-based
> metrics (`rent.median_2br`, etc.) are not rankable yet — for rent on a single
> named area, use `/rentometer-atlas-facts`.

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`.

## Step 1 — pick a metric (and confirm you may use it)

Metric keys are dotted, e.g. `acs.median_household_income`. If you don't already
know the exact key, list the catalog (free, no credit charge):

```bash
curl -sS "https://www.rentometer.com/api/v1/atlas/metrics" \
  --get \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

```jsonc
{
  "metrics": [
    {
      "key": "acs.median_household_income",
      "label": "Median household income",
      "unit": "usd",
      "family": "acs",
      "default_order": "desc",            // natural "top" direction
      "area_types": ["state","metro","county","place","zcta"],
      "requires_flag": "atlas_show_acs_facts",
      "entitled": true                    // false → your account can't rank by this
    }
  ]
}
```

**Only use a metric whose `entitled` is `true`.** If the user asks to rank by a
metric where `entitled` is `false`, don't call rankings — tell them the metric
needs a data entitlement on their account and point them at
https://www.rentometer.com/rentometer-api/settings. (Ranking on an
un-entitled metric returns `403`.)

## Step 2 — resolve the parent area (only if scoping with `within`)

If the user scopes the request ("…in the Cincinnati metro", "…in Ohio"), turn
that place name into a slug with `/rentometer-atlas-search` first, and pass it as
`within`. Omit `within` for a country-wide ranking.

## Step 3 — make the ranking call

```bash
curl -sS "https://www.rentometer.com/api/v1/atlas/rankings" \
  --get \
  --data-urlencode "area_type=metro" \
  --data-urlencode "metric=acs.median_household_income" \
  --data-urlencode "limit=10" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

Parameters:

- `area_type` (required) — what kind of area to rank: `metro`, `city` (alias
  `place`), `county`, `zcta` (alias `zip`), `neighborhood`, `school_district`,
  `state`. Must be one of the metric's `area_types`, or you get a `422`.
- `metric` (required) — a `key` from `/rentometer-metrics`.
- `within` (optional) — parent Atlas slug; omit for country-wide.
- `order` (optional) — `desc` or `asc`. Defaults to the metric's
  `default_order` (e.g. income defaults to `desc` = highest first; unemployment
  defaults to `asc` = lowest first). Set it explicitly when the user says
  "lowest" / "highest" to be safe.
- `limit` (optional) — 1–100, default 10.
- `offset` (optional) — for paging ("show me 11–20").

## Response shape (annotated)

```jsonc
{
  "metric": { "key": "acs.median_household_income", "label": "Median household income", "unit": "usd", "family": "acs" },
  "area_type": "metro",
  "within": null,                         // or { "slug": "...", "display_name": "..." }
  "order": "desc",
  "total_candidates": 384,                // how many areas had this metric
  "rankings": [
    {
      "rank": 1,
      "slug": "san-jose-sunnyvale-santa-clara-ca-metro",
      "display_name": "San Jose-Sunnyvale-Santa Clara, CA Metro",
      "area_type": "MetroGeometry",
      "type": "Metro",
      "value": 153792.0,                  // interpret with metric.unit
      "context": { "sample_count": 1840, "record_density": 24.1 },
      "links": [
        { "rel": "facts",   "href": "https://www.rentometer.com/api/v1/atlas/facts?slug=..." },
        { "rel": "summary", "href": "https://www.rentometer.com/api/v1/summary?slug=..." }
      ]
    }
  ],
  "credits_remaining": 411,
  "generated_at": "2026-05-29T14:00:00Z"
}
```

- Format `value` using `metric.unit`: `usd` → `$153,792`; `percent` → `3.4%`;
  `count` → `1,840`.
- Each row's `links.facts` is the natural drill-down: if the user wants detail on
  one of the ranked areas, call `/rentometer-atlas-facts` with that slug.

## Present to the user

A numbered or ranked table: **rank · area · value** (formatted per unit). Lead
with what was ranked and the scope ("Top 10 metros nationwide by median
household income"). If `within` was set, name the parent area. Mention
`total_candidates` when it's informative ("of 384 metros with this data"). Offer
to pull the full bundle for any row via `/rentometer-atlas-facts`.

## Errors

- `400` → unknown `metric` (run `/rentometer-metrics`) or missing/unknown
  `area_type`.
- `401` → API key issue; run `/rentometer-login`.
- `402` → out of quickview credits; refill at
  https://www.rentometer.com/rentometer-api/settings.
- `403` → your account isn't entitled to that metric. Don't retry; tell the user.
- `404` → the `within` slug doesn't exist. Re-resolve via
  `/rentometer-atlas-search`.
- `422` → that metric isn't published for that `area_type` (e.g. building
  permits aren't published at ZIP level). Pick an `area_type` from the metric's
  `area_types` list.

## When to use this vs other skills

| Want | Use |
|---|---|
| A leaderboard of areas by a metric ("top N …") | `/rentometer-rankings` (this skill) |
| The list of rankable metrics + your entitlements | `/rentometer-metrics` (free; usually called by this skill) |
| Everything about one named area | `/rentometer-atlas-facts` |
| Rent for one address | `/rentometer-summary <address>` |
| Turn a place name into a slug | `/rentometer-atlas-search` |
