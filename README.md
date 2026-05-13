# Rentometer Skills for Claude Code

A set of [Claude Code](https://claude.com/claude-code) skills that turn any agent
session into a Rentometer-powered rental analyst. Drop in an address, get back
real rent comps, market stats, and full investment analysis — backed by
Rentometer's first-party data instead of scraped listings.

## Skills

| Skill | What it does | Cost (Rentometer credits) | Auth |
|---|---|---|---|
| `/rentometer-login` | One-time setup: validate + store your Rentometer API key | free | — |
| `/rentometer-summary` | Rent stats (mean/median/percentiles) for an address | 1 quickview | Pro API key |
| `/rentometer-comps` | The individual comparable listings backing a search | 1 premium | Pro API key |
| `/rentometer-batch` | Run summary on N properties at once | N quickview | Pro API key |
| `/rentometer-property-rents` | Historical rents for one exact address | 1 premium | Pro API key |
| `/rentometer-report` | Generate + download a Pro PDF report | 1 pro_report | Pro API key |
| `/rentometer-area` | Public rent stats for a metro/city/ZIP/school district | free | none |
| `/rentometer-area-search` | Find the area ID for a place name | free | none |
| `/rentometer-quota` | Check API rate-limit usage | free | Pro API key |
| `/rentometer-analyze` | Flagship: multi-agent full investment analysis | ~2 quickview + 1 premium | Pro API key |

## Install

Skills live in `~/.claude/skills/` (user-level) or `.claude/skills/` (per-project). Pick whichever you prefer.

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/rentometer/rentometer2/main/claude-skills/install.sh | bash
```

### From this repo

```bash
git clone https://github.com/rentometer/rentometer2.git
mkdir -p ~/.claude/skills
cp -R rentometer2/claude-skills/skills/* ~/.claude/skills/
```

### Verify

Start `claude` and type `/rentometer` — autocomplete should list every skill above.

## Authentication

Most skills require a Rentometer Pro API key. The easiest path:

```text
/rentometer-login
```

That skill walks you through:

1. Opening https://www.rentometer.com/rentometer-api/settings to generate or
   copy a key (Pro subscription with API access required)
2. Pasting the key (never echoed back)
3. Validating it against `/api/v1/rate_limit` before saving
4. Storing it at `~/.config/rentometer/api_key` with `0600` perms
5. Optionally appending `export RENTOMETER_API_KEY=…` to your shell rc

### How skills find the key

Every Pro-gated skill resolves credentials in this order:

```bash
RENTOMETER_API_KEY="${RENTOMETER_API_KEY:-$(cat ~/.config/rentometer/api_key 2>/dev/null || true)}"
```

So either approach works:

- **Recommended**: run `/rentometer-login` once; skills read the saved file
- **CI / shared shells**: set `$RENTOMETER_API_KEY` as an environment variable

The key is sent only as `Authorization: Bearer …` to `rentometer.com`. It is
never passed on the command line (no shell-history leakage) and never written
to logs.

Credit balance, plan tier, and rate limits are enforced server-side by your
existing Rentometer Pro subscription — no extra configuration needed.

### Logging out

```text
/rentometer-login
```

Tell the skill you want to log out, or just run:

```bash
rm -f ~/.config/rentometer/api_key
unset RENTOMETER_API_KEY
```

## Why these are different from "AI real estate" skills you've seen elsewhere

Most agent-based real-estate analyzers scrape Zillow / Redfin / Realtor.com at
runtime. That approach is slow, expensive in tokens, blocked by anti-bot rules
half the time, and prone to hallucinating "comps" from cached snippets.

Rentometer maintains a curated rental-listing dataset spanning millions of
properties. These skills hit that dataset directly via the same authenticated
API that powers `rentometer.com`. The result:

- **Lower cost**: one API call instead of dozens of scraped pages
- **Faster**: subsecond response vs minutes of agent crawling
- **Less hallucination**: comp counts, addresses, prices are ground-truth
- **Cleaner attribution**: every comp links back to a real listing source

The `/rentometer-analyze` skill still uses Claude sub-agents for the things
agents are actually good at — neighborhood/school/crime research, cash-flow
math, strategy comparison — but anchors the *rental* numbers on real data.

## Getting a Pro subscription

The credit-charging skills need a Rentometer Pro plan with API access enabled.
See pricing: https://www.rentometer.com/pricing

The free `/rentometer-area` and `/rentometer-area-search` skills work without
any subscription.

## Issues / contributions

File issues against this repo. PRs welcome — each skill is a single
`SKILL.md` file under `claude-skills/skills/<name>/`.
