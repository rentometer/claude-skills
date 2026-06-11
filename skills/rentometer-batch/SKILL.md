---
name: rentometer-batch
description: Run a Rentometer rent analysis on many properties at once via /api/v1/batch_summary. Costs 1 quickview credit per property. Use when the user has a list/CSV/portfolio of addresses and wants stats for each — e.g. "analyze these 30 properties", "compare rents across my portfolio", "process this spreadsheet of addresses".
---

# Rentometer Batch Summary

Submit a batch of properties for rent analysis. The endpoint returns a `batch_id` immediately; results are computed asynchronously and you poll for them.

## What you need

An array of properties. Each property MUST have:
- `address` OR (`latitude` + `longitude`)
- `bedrooms`

Each property MAY have: `baths`, `building_type`, `look_back_days`.

You can also pass top-level `defaults` (`look_back_days`, `baths`, `building_type`) that apply to every property unless overridden.

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`. Each property in the batch consumes 1 quickview credit — verify the user has enough first via `/rentometer-quota` if the batch is large.

## Step 1 — Submit

```bash
curl -sS -X POST "https://www.rentometer.com/api/v1/batch_summary" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": [
      {"address": "100 Main St, Cincinnati, OH", "bedrooms": 2},
      {"address": "200 Elm St, Cincinnati, OH", "bedrooms": 3, "baths": "1.5+"}
    ],
    "defaults": {"look_back_days": 365}
  }'
```

Response:
```json
{
  "batch_id": "abc123...",
  "status": "pending",
  "properties_count": 2,
  "poll_url": "https://www.rentometer.com/api/v1/batch_summary/abc123..."
}
```

## Step 2 — Poll

Poll the `poll_url` (GET, same auth header) every ~10 seconds. The `status` will progress through `pending` → `processing` → `complete` (or `failed`). When complete, the response includes a `results` array, one entry per submitted property, with the same fields as `/rentometer-summary` (median, mean, percentiles, samples, etc.).

Cap polling at ~10 minutes for safety. Use bash `until` with `sleep 10`.

## Errors

- `402 Insufficient credits. Need N, have M` → wallet doesn't cover the batch; refill or trim the list
- `422` with field errors → one or more properties are invalid; the error message names which

## Present results

Render a table: address, median rent, samples, status (ok/insufficient_data/error). Call out any rows with samples < 10 (low-confidence) or errors. If the user provided a CSV, offer to write the results back to a CSV file in the working directory.

## See also — area enrichment for portfolio analysis

If the batch is a portfolio across multiple ZIPs / metros, it's often more useful to also pull `/rentometer-atlas-facts` for each **unique area** in the result set rather than each individual property. Pseudocode:

1. From batch results, extract unique ZIPs (parse from each geocoded address)
2. For each unique ZIP: `/rentometer-atlas-search q=<ZIP>` → `/rentometer-atlas-facts slug=<best_match>`
3. Join the area-level numbers (median, ACS, HUD FMR, unemployment) back to each property row

That gives the user a per-property rent estimate **plus** market context (is this ZIP affordable for renters? what's the unemployment trend? are new permits eating supply?). 1 quickview credit per unique area, on top of the N quickview credits the batch already charges.

For full agentic investment analysis on each batch row, run `/rentometer-deep-analysis` on each address individually — but that's expensive at scale (~5 sub-agents × N properties). For a lighter per-property read, `/rentometer-quick-analysis` is much cheaper.
