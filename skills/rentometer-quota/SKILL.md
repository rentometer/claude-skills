---
name: rentometer-quota
description: Check the user's Rentometer API rate-limit usage and credit balance. Free — does not consume credits. Use before a large batch, when a 402/429 error fires, or when the user asks "how many credits do I have left", "am I rate limited", "what's my Rentometer quota".
---

# Rentometer Quota / Rate Limit

Check current rate-limit usage. Free to call.

## Make the call

```bash
curl -sS -i "https://www.rentometer.com/api/v1/rate_limit" \
  -H "Authorization: Bearer $RENTOMETER_API_KEY"
```

## Response body

```json
{
  "dimension": "api_key",
  "key_prefix": "abc123",
  "tier": "pro",
  "windows": {
    "minute": {"limit": 60,   "used": 4,   "remaining": 56,   "reset_at": "..."},
    "hour":   {"limit": 1000, "used": 87,  "remaining": 913,  "reset_at": "..."},
    "day":    {"limit": 10000,"used": 412, "remaining": 9588, "reset_at": "..."}
  }
}
```

## Response headers (any API call sets these)

Worth knowing — every Rentometer API response includes these whether or not you call `/rate_limit`:

- `X-RateLimit-Usage: minute=4/60;hour=87/1000;day=412/10000`
- `X-RateLimit-Dimension: api_key`
- `X-RateLimit-Tier: pro`
- `X-RateLimit-Policy: minute=60;hour=1000;day=10000`

## Credit balance (separate from rate limits)

The rate-limit endpoint does NOT report wallet credit balance. Credits show up as `credits_remaining` in the response of any credit-charging call (`/rentometer-summary`, `/rentometer-comps`, etc.). To check the wallet without burning a credit, the user can visit https://www.rentometer.com/rentometer-api/settings.

## Present to the user

Show the most-constrained window (usually `hour` or `day`). Flag if any window is >80% used. If they asked about credits specifically, point them at the settings page or note the last `credits_remaining` value seen in this session.
