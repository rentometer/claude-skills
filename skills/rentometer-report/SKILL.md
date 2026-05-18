---
name: rentometer-report
description: Request a full Rentometer Pro PDF report (charts, comps map, deeper stats) for a property, then poll until ready and download the PDF. Costs 1 pro_report credit. Use when the user wants a "full report", "PDF report", "Pro report", or something they can send to a client/lender — not just inline stats.
---

# Rentometer Pro Report (PDF)

Three-step workflow: request → poll → download. Requires a `token` from a prior `/rentometer-summary` call (the token identifies which search to render).

## Auth

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

If still empty, tell the user to run `/rentometer-login`.

## Step 0 — Get a token

If you don't already have one, run `/rentometer-summary` first. Grab the `token` field from its response.

## Step 1 — Request the report

```bash
curl -sS "https://www.rentometer.com/api/v1/request_pro_report" \
  --get \
  --data-urlencode "token=$TOKEN" \
  --data-urlencode "tool=claude-skills" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

This charges 1 pro_report credit and queues the PDF build. Response includes a `check status` link.

## Step 2 — Poll for status

```bash
curl -sS -i "https://www.rentometer.com/api/v1/pro_report_status" \
  --get \
  --data-urlencode "token=$TOKEN" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

Status progression:
- `202` with `status: "in queue, retry later"` and a `Retry-After: 5` header → wait, poll again
- `303` with `status: "ready"` and a `links` array containing `{rel: "download", href: <url>}` → PDF is built. The `Location` response header also points at the same URL.

Use `bash until` with `sleep 5`. Cap at ~3 minutes; if it's still queued, surface that to the user and offer to check again later.

## Step 3 — Download

Pull the URL from the `download` entry of `links[]` (or just use the `Location` header). It points at `/api/v1/download_pro_report` and serves the PDF when `download=true` is passed:

```bash
curl -sSL -o "rentometer-report-$TOKEN.pdf" \
  "https://www.rentometer.com/api/v1/download_pro_report?token=$TOKEN&download=true" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

Save to the user's current working directory by default; ask if they want a specific path.

## Errors

- `400 Pro Report not requested` → call `/api/v1/request_pro_report` first (step 1)
- `402` → out of pro_report credits; refill page is https://www.rentometer.com/rentometer-api/settings
- `404 Report not found or not yet ready` → the build failed or hasn't completed; re-check status

## Present to the user

Tell them the file path of the saved PDF and the report token. Offer to open it if you can (`xdg-open`/`open` depending on platform — ask first).
