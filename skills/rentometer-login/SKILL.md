---
name: rentometer-login
description: Set up authentication for the Rentometer skills. Validates a Rentometer API key and stores it locally so subsequent /rentometer-* skills can call the Pro API. Use when the user hasn't configured a key yet, when other skills return 401, or when the user says "log in to Rentometer", "set my Rentometer API key", "rentometer auth".
---

# Rentometer Login

Configure the API credential used by every Pro-gated `/rentometer-*` skill in this package. Credentials are stored on-disk in the user's config dir with 0600 perms; nothing leaves the local machine except a single validation call to Rentometer.

## Step 1 — Check current state first

Don't reconfigure if a working credential is already present. Run:

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

- `200` → already authenticated. Tell the user, offer to run `/rentometer-quota` to show their usage, and stop. Don't overwrite a working key without permission.
- `401` → stored key is invalid; proceed to Step 2 (and offer to delete the bad file).
- Empty / no key → proceed to Step 2.

## Step 2 — Walk the user through getting a key

Print, verbatim:

> Generate (or copy) a Rentometer API key here:
> **https://www.rentometer.com/rentometer-api/settings**
>
> Requires an active Pro subscription with API access enabled. If you don't
> have one yet, the free `/rentometer-area` skill works without a key.

Then ask: "Want me to open that page in your browser?"

If yes:
```bash
# macOS
open "https://www.rentometer.com/rentometer-api/settings" 2>/dev/null \
  || xdg-open "https://www.rentometer.com/rentometer-api/settings" 2>/dev/null \
  || echo "(Open the URL above manually)"
```

Don't open the URL without asking.

## Step 3 — Take the pasted key

Ask: "Paste your API key here when ready." Treat the input as secret:
- Do **not** echo it back in any tool call output
- Do **not** include it in markdown blocks the user will see
- Do **not** write it to any file other than the credential file in Step 5

## Step 4 — Validate before saving

Call `/api/v1/rate_limit` (free, no credit cost) to confirm the key works:

```bash
PASTED_KEY=<the key from the user>
HTTP=$(curl -sS -o /tmp/.rentometer-validate -w "%{http_code}" \
  "https://www.rentometer.com/api/v1/rate_limit" \
  -H "Authorization: Bearer $PASTED_KEY")
rm -f /tmp/.rentometer-validate
echo "Validation: $HTTP"
```

- `200` → valid; proceed to Step 5
- `401` → invalid; ask user to recheck. Common causes: copied the wrong string, key was revoked, Pro subscription expired.
- `429` → valid but rate-limited right now. Accept it.
- Other → network issue; surface the status code.

## Step 5 — Save the credential

Write to `~/.config/rentometer/api_key` with restrictive perms:

```bash
mkdir -p "$HOME/.config/rentometer"
chmod 700 "$HOME/.config/rentometer"
( umask 077 && printf '%s' "$PASTED_KEY" > "$HOME/.config/rentometer/api_key" )
chmod 600 "$HOME/.config/rentometer/api_key"
```

Confirm to the user: "Saved to `~/.config/rentometer/api_key`."

## Step 6 — Offer to persist as env var (optional)

Some users like having `$RENTOMETER_API_KEY` set in every shell. Ask:

> Want me to add an `export RENTOMETER_API_KEY=…` line to your shell rc so it's available everywhere? (Skills work fine without this — they'll fall back to the saved file.)

If yes, detect the shell and append to the right rc file:

```bash
SHELL_RC=""
case "$(basename "$SHELL")" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
esac
```

Skip if already present (grep for `RENTOMETER_API_KEY`). For zsh/bash:
```bash
echo 'export RENTOMETER_API_KEY="$(cat $HOME/.config/rentometer/api_key 2>/dev/null || true)"' \
  >> "$SHELL_RC"
```

For fish:
```bash
echo 'set -gx RENTOMETER_API_KEY (cat ~/.config/rentometer/api_key 2>/dev/null; or echo "")' \
  >> "$SHELL_RC"
```

Tell them to `source "$SHELL_RC"` or open a new shell.

## Step 7 — Confirm and suggest next steps

> Authentication configured. Try:
> - `/rentometer-quota` — confirm usage limits and tier
> - `/rentometer-summary <address> <bedrooms>` — get rent stats for a property
> - `/rentometer-analyze <address>` — full multi-agent investment analysis

## Logout

If the user says "log out", "remove my Rentometer key", or "delete credentials":

```bash
rm -f "$HOME/.config/rentometer/api_key"
echo "Removed ~/.config/rentometer/api_key"
```

Tell them to also `unset RENTOMETER_API_KEY` in the current shell and remove any export line from their shell rc (point them at the line you added in Step 6, if any). Don't edit their rc to remove it without asking.

## Security notes

- Never include the key value in a markdown code block visible to the user.
- Never pass the key as a CLI argument (it'd show up in `ps`/shell history). Always use the `Authorization: Bearer` header.
- The credential file is per-user (`0600`); on a multi-user host, anyone with root can still read it. Rentometer treats keys as bearer credentials with no second factor — rotating the key in settings invalidates the stolen copy.
