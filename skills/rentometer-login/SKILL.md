---
name: rentometer-login
description: Set up authentication for the Rentometer skills using the OAuth 2.0 device authorization flow (browser-based, no key copy-paste). Falls back to manual key entry if requested. Use when the user hasn't configured a key yet, when other skills return 401, or when the user says "log in to Rentometer", "set my Rentometer API key", "rentometer auth".
---

# Rentometer Login

Configure the API credential used by every Pro-gated `/rentometer-*` skill in this package. The default flow is browser-based (RFC 8628 device authorization grant) — the user signs into rentometer.com in their browser, the CLI receives the key automatically. Credentials are stored on-disk in the user's config dir with `0600` perms; nothing leaves the local machine except the device-flow API calls.

## Step 1 — Check current state first

Don't reconfigure if a working credential is already present:

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
if [[ -n "$RENTOMETER_API_KEY" ]]; then
  echo "Found existing credential — validating…"
  HTTP=$(curl -sS -o /dev/null -w "%{http_code}" \
    "https://www.rentometer.com/api/v1/rate_limit" \
    -H "Authorization: Bearer $RENTOMETER_API_KEY")
  echo "Status: $HTTP"
fi
```

- `200` → already authenticated. Tell the user, offer to run `/rentometer-quota`, and stop. Don't overwrite a working key without permission.
- `401` → stored key is invalid; proceed to Step 2 (and offer to delete the bad file).
- Empty / no key → proceed to Step 2.

## Step 2 — Request a device code

Hit the device-authorization endpoint to mint a code pair:

```bash
RESPONSE=$(curl -sS -X POST "https://www.rentometer.com/api/v1/auth/device/code" \
  --data-urlencode "client_name=rentometer-claude-skills")
echo "$RESPONSE"
```

Parse the response. The fields you need are:

- `device_code` — secret, used to poll for the token
- `user_code` — short human-readable code shown to the user (e.g. `BCDF-GHJK`)
- `verification_uri_complete` — the URL to send the user to (includes the user_code as a path segment)
- `interval` — seconds between polls (typically 5)
- `expires_in` — total seconds before the request expires (typically 600)

If `jq` is available: `device_code=$(echo "$RESPONSE" | jq -r '.device_code')` etc. If not, use `ruby -rjson -e 'puts JSON.parse(STDIN.read)["device_code"]' <<< "$RESPONSE"` or `python3 -c 'import json,sys; print(json.load(sys.stdin)["device_code"])'`.

## Step 3 — Send the user to the browser

Display the user_code and verification URL prominently. Print verbatim:

> **Open this URL in your browser to authorize:**
> {verification_uri_complete}
>
> The page will ask you to sign in to rentometer.com (or sign up if you don't
> have an account) and confirm the code:
> **{user_code}**
>
> Waiting for authorization…

Ask once: "Want me to open the URL in your browser?" If yes:

```bash
open "$VERIFICATION_URI_COMPLETE" 2>/dev/null \
  || xdg-open "$VERIFICATION_URI_COMPLETE" 2>/dev/null \
  || start "" "$VERIFICATION_URI_COMPLETE" 2>/dev/null \
  || echo "(Open the URL above manually)"
```

Don't open the URL without asking.

## Step 4 — Poll for the token

Loop on `POST /api/v1/auth/device/token` every `interval` seconds. Cap the total loop at `expires_in` seconds (typically 10 min).

```bash
DEADLINE=$(( $(date +%s) + EXPIRES_IN ))
WAIT=$INTERVAL

while [[ $(date +%s) -lt $DEADLINE ]]; do
  TOKEN_RESPONSE=$(curl -sS -X POST "https://www.rentometer.com/api/v1/auth/device/token" \
    --data-urlencode "device_code=$DEVICE_CODE")

  ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // empty')

  case "$ERROR" in
    "")  # success
      PASTED_KEY=$(echo "$TOKEN_RESPONSE" | jq -r '.api_key')
      ACCOUNT_EMAIL=$(echo "$TOKEN_RESPONSE" | jq -r '.account_email')
      break
      ;;
    authorization_pending)
      sleep "$WAIT"
      ;;
    slow_down)
      WAIT=$((WAIT + 5))
      sleep "$WAIT"
      ;;
    expired_token)
      echo "Code expired. Re-run /rentometer-login to start over."
      exit 1
      ;;
    access_denied)
      echo "Authorization was denied in the browser."
      exit 1
      ;;
    *)
      echo "Unexpected error: $ERROR"
      exit 1
      ;;
  esac
done

if [[ -z "${PASTED_KEY:-}" ]]; then
  echo "Authorization timed out. Try again."
  exit 1
fi
```

During the wait, give the user a heartbeat so they don't think the skill hung — e.g. print a dot or "Still waiting…" every few iterations. Don't print the device_code or the eventual API key.

## Step 5 — Save the credential

Write to `~/.config/rentometer/api_key` with restrictive perms. **Never echo the key back to the user or include it in tool-result text.**

```bash
mkdir -p "$HOME/.config/rentometer"
chmod 700 "$HOME/.config/rentometer"
( umask 077 && printf '%s' "$PASTED_KEY" > "$HOME/.config/rentometer/api_key" )
chmod 600 "$HOME/.config/rentometer/api_key"
```

Confirm to the user: "Saved credential for `<account_email>` to `~/.config/rentometer/api_key`."

## Step 6 — Offer to persist as env var (optional)

Same as before — ask once, append to `~/.zshrc` / `~/.bashrc` / `~/.config/fish/config.fish` only if they say yes:

```bash
export RENTOMETER_API_KEY="$(cat $HOME/.config/rentometer/api_key 2>/dev/null || true)"
```

## Step 7 — Confirm and suggest next steps

> Authentication configured. Try:
> - `/rentometer-quota` — confirm usage limits and tier
> - `/rentometer-summary <address> <bedrooms>` — get rent stats for a property
> - `/rentometer-analyze <address>` — full multi-agent investment analysis

## Fallback: manual key entry

If the user can't use a browser (CI environments, headless boxes, etc.) or explicitly asks to paste a key directly, fall back to the legacy flow:

1. Ask them to generate a key at https://www.rentometer.com/rentometer-api/settings
2. Ask them to paste it. Treat input as secret — do not echo back.
3. Validate via `curl /api/v1/rate_limit` with the pasted key. Reject if non-200.
4. Save to `~/.config/rentometer/api_key` exactly as in Step 5.

## Logout

If the user says "log out", "remove my Rentometer key", or "delete credentials":

```bash
rm -f "$HOME/.config/rentometer/api_key"
echo "Removed ~/.config/rentometer/api_key"
```

Tell them to also `unset RENTOMETER_API_KEY` in the current shell and remove any export line from their shell rc.

## Security notes

- Never include the key value in a markdown code block visible to the user.
- Never pass the key as a CLI argument (it'd show up in `ps`/shell history). Always use the `Authorization: Bearer` header.
- The credential file is per-user (`0600`); on a multi-user host, anyone with root can still read it. Rotating the key in the user's account settings invalidates any stolen copy.
- The device_code is also sensitive while authorization is pending — keep it in shell variables, not on disk.
