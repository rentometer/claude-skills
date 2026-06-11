---
name: rentometer-quick-analysis
description: Fast, no-frills rental snapshot for a single address or a named area. Gets the rent summary (mean/median/percentiles/sample size) AND a tight digest of the surrounding area's Atlas facts (demographics, fair-market rents, unemployment, permits) — in two calls, no sub-agents, no graded report. Costs ~2 quickview credits (address) or 1 (area). Use when the user wants "a quick read on [address]", "rent + the basics for this place", "what's the rent and what's the area like", or a lightweight first look before deciding whether to go deeper. For the full multi-agent investment analysis with scoring/cashflow/strategy, use /rentometer-deep-analysis instead.
---

# Rentometer Quick Analysis

A lightweight snapshot: **what does it rent for** + **what's the surrounding area like**, with no sub-agent fan-out and no grading. Two API calls, a clean table, done. This is the everyday "give me the basics" skill. When the user wants a graded investment verdict (cashflow, strategy, scoring), point them at `/rentometer-deep-analysis`.

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`. Don't try to walk them through it inline.

## Phase 0 — route on input

- **Address-like** (street number + street + city/state, or a pasted listing URL) → **Address path**.
- **Area-like** (place name, ZIP, neighborhood, city, metro, school district — no street number) → **Area path**.
- **Ambiguous** ("Cincinnati") → ask one clarifying question, then route.

Always pass `tool=claude-skills` on every call so Rentometer can attribute usage.

## Address path

### 1. Rent summary

Confirm the address + `bedrooms` (ask if missing — don't guess). Then call `/api/v1/summary`:

```bash
curl -sS "https://www.rentometer.com/api/v1/summary" \
  --get \
  --data-urlencode "address=$ADDRESS" \
  --data-urlencode "bedrooms=$BEDROOMS" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY" \
  -H "Accept: application/json"
```

Add `baths`, `building_type`, `look_back_days` only if the user supplied them. Capture the whole response — you need `median`, `samples`, the percentile ladder, `quickview_url`, `token`, and the **`atlas` array** (see next step).

**If `samples < 5`, warn the user the rent read is thin** before continuing.

### 2. Pull the surrounding area's Atlas facts — the cheap way

A point/address summary now returns an **`atlas` array**: the bounded geographies that contain the searched point, broadest → narrowest, each as `{slug, geoid, name, type, area_type}`. This means **no separate geocode/search round-trip** — the slug you need is already in the summary response.

1. From `response.atlas`, pick the **most specific** area that's useful — prefer a `place`/`city` or `zcta`/`zip` entry over the metro/county. (More specific = more relevant neighborhood read.)
2. Call `/api/v1/atlas/facts` with that slug:

```bash
curl -sS "https://www.rentometer.com/api/v1/atlas/facts" \
  --get \
  --data-urlencode "slug=$SLUG" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

3. If that slug's facts come back thin (few `facts.*` keys), fall back to the parent (next-broader entry in the `atlas` array, e.g. the city or metro) and use that instead.

**Fallback when `atlas` is absent** (the `atlas_api_geo_linkage` flag is off for this account): extract the 5-digit ZIP from the geocoded `address` string in the summary response (e.g. `45208` in `"Cincinnati, OH 45208, USA"`), call `/api/v1/atlas/search?q=<ZIP>` (free), take the top match's `slug`, then call `/atlas/facts` on it. If no ZIP, search `City, ST`.

## Area path

1. `/api/v1/atlas/search?q=<place name>` (free) to resolve the slug. If multiple plausible matches, ask the user which one — don't guess. (You can also pass `geoid=<FIPS or ZCTA>` instead of `q` if the user gave you a code.)
2. `/api/v1/atlas/facts?slug=<slug>` — one call returns rent breakdown PLUS whichever `facts.*` sources the account is entitled to. That's the whole snapshot; no summary call needed.

## Atlas facts — what comes back

`facts.*` sources are each gated behind a per-account Flipper flag. **A missing key means "not available to you / no data" — there's no access-denied marker.** Only present what actually came back; never promise a section that didn't return. Possible keys: `acs` (demographics), `hud_fmr` (fair-market rents), `hud_chas` (affordability), `bls_laus` (unemployment), `bls_qcew` (industry/wages), `census_bps` (building permits).

## Output

Keep it compact — this is the *quick* skill. One screen:

1. **Header** — address (or area name) + input mode.
2. **Rent** — a small table: median, mean, 25th–75th percentile, samples. One line on confidence ("23 comps within 2 mi — solid" / "only 4 comps — thin, treat as directional"). Include `quickview_url`.
3. **Area snapshot** — 4–8 bullets pulled straight from `facts.*`: median household income (acs), HUD 2BR FMR (hud_fmr), unemployment rate + month (bls_laus), recent permits (census_bps), cost-burdened renters (hud_chas) — **only the sources present**. One short line each, no analysis essay.
4. **Credits remaining** (from the last response).

Then offer the next step:
> "Want the full graded analysis (cashflow, strategy, scoring)? Run `/rentometer-deep-analysis`. Want a client-ready PDF? Run `/rentometer-report`."

## Cost

- **Address path:** 2 quickview credits (summary + atlas-facts). `atlas-search` is free and usually not even needed.
- **Area path:** 1 quickview credit (atlas-facts). `atlas-search` is free.

Tell the user the cost up front. If `$RENTOMETER_API_KEY` is unset, route them to `/rentometer-login` first.

## Errors

- `401` → key issue; `/rentometer-login`.
- `402` → out of quickview credits; refill at https://www.rentometer.com/rentometer-api/settings.
- `404 Address not found` → ask for a more specific address or lat/lng.
- `422` → not enough properties; suggest widening `look_back_days` or dropping `baths`/`building_type`.

## When to use this vs other skills

| Want | Use |
|---|---|
| Quick rent + area basics | **this skill** |
| Full graded investment analysis (cashflow, strategy, scoring, sub-agents) | `/rentometer-deep-analysis` |
| Just rent stats, nothing else | `/rentometer-summary` |
| Everything Rentometer knows about an area | `/rentometer-atlas-facts` |
| The actual comp listings | `/rentometer-comps` |
| A client/lender PDF | `/rentometer-report` |
