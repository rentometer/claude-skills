---
name: rentometer-analyze
description: Run a full multi-agent rental analysis. Routes on the user's input — for a specific address, anchors on first-party Rentometer comps and fans out to parallel sub-agents for neighborhood / cashflow / market / strategy analysis. For a named area (metro / city / ZIP / neighborhood), anchors on the Rentometer Atlas first-party bundle (rent + ACS demographics + HUD FMR + BLS unemployment + Census permits) and runs a leaner sub-agent set since the area-research is already done. Costs ~2 quickview + 1 premium credit (address path) or ~1 quickview (area path). Use when the user asks for a "full analysis", "investment analysis", "should I buy [address]", "should I invest in [neighborhood/ZIP]", or pastes a listing.
---

# Rentometer Full Property / Area Analysis

The flagship skill. Other Claude Code real-estate skills scrape Zillow/Redfin/GreatSchools/BLS at runtime — this one runs Rentometer's first-party data as the trusted backbone and uses Claude only for the analysis layer. Faster, cheaper, fewer hallucinations.

## Phase 0 — Route on input shape

Look at what the user gave you:

- **Address-like** (has a street number, street, city, state) → run the **Address path** (Phase 1A → Phase 2A → Phase 3)
- **Area-like** (a place name, ZIP code, neighborhood, school district, metro — no street number) → run the **Area path** (Phase 1B → Phase 2B → Phase 3)
- **Ambiguous** ("Cincinnati" — could be the city or shorthand for a deal there) → ask the user one clarifying question, then route

If a listing URL is pasted, treat it as address-like.

## Phase 1A — Address path: anchor on first-party comps

Run synchronously:

1. Confirm address + bed/bath from the listing (or ask).
2. Run `/rentometer-summary` for the address. Capture the response and the `token`.
3. Run `/rentometer-comps` with the token. Capture the comp list.

Stop and warn the user if `samples < 5` — the analysis won't be reliable.

## Phase 1B — Area path: anchor on first-party Atlas

Run synchronously:

1. Run `/rentometer-atlas-search` to resolve the user's place name. If multiple plausible matches, ask the user to pick. Capture the chosen `slug` and `area_type`.
2. Run `/rentometer-atlas-facts` with the slug. **This single call returns rent breakdown PLUS demographics PLUS fair-market rents PLUS unemployment PLUS industry/wage data PLUS building permits.** Capture the whole bundle.

That's it. One credit, one call, no web scraping. Most of what the address-path sub-agents would research is already in this response — the sub-agent fan-out below is correspondingly leaner.

## Phase 2A — Address path: full sub-agent fan-out (5 agents in parallel)

Dispatch five sub-agents in parallel (single message with five Agent tool calls). Each gets the Phase 1A data (summary + comps + address) in its prompt.

| Sub-agent | What it produces |
|---|---|
| **comps-analyst** | Reviews comps from Phase 1A. Outlier detection, sample quality, distance distribution. Confidence-banded fair-market rent estimate. Score: comp quality 0–100. |
| **cashflow-analyst** | Asks user (or estimates) purchase price, down payment %, interest rate, taxes, insurance, HOA, vacancy %, mgmt %. Computes monthly + annual cash flow, cap rate, cash-on-cash return, GRM, DSCR. Score: income potential 0–100. |
| **neighborhood-analyst** | Web-searches school ratings (GreatSchools), crime stats, walkability, demographics. Score: neighborhood quality 0–100. |
| **market-analyst** | Web-searches local-market signals: months of supply, list-to-sale ratio, days on market, year-over-year price/rent change, new construction permits. Buyer's vs seller's market call. Score: market conditions 0–100. |
| **strategy-analyst** | Evaluates buy-and-hold, BRRRR, and fix-and-flip across 5/10-year horizons in bull/base/bear cases. Strategy depends on the others' inputs — dispatch it last or roll into Phase 3. Score: investment upside 0–100. |

Each sub-agent's prompt should include the Phase 1A summary + comps JSON, the user's stated goal, and:
> "Return a JSON object with `score`, `signal`, `key_findings` (3–5 bullets), `risks` (2–3 bullets), and `sources` (URLs you cited)."

## Phase 2B — Area path: leaner sub-agent set (3 agents in parallel)

The Atlas facts bundle already supplies what `neighborhood-analyst` and `market-analyst` would web-scrape. Drop those two. Run only three sub-agents:

| Sub-agent | What it produces |
|---|---|
| **rent-analyst** | Reads the Atlas `rent_breakdown` (overall, per-bedroom, per-property-type). Calls out which bed/bath/property-type combos are most numerous (high confidence) and which are sparse. Flags any unusual spreads. Score: comp quality 0–100. |
| **area-analyst** | Reads the Atlas `facts` bundle — ACS demographics, HUD FMR, HUD CHAS, BLS LAUS, BLS QCEW, Census BPS. Synthesizes a coherent picture of the area's economic health, supply/demand balance, and resident profile. **Note which facts keys are absent and don't speculate about them.** Score: area quality 0–100 (single combined score replacing the neighborhood + market scores from the address path). |
| **strategy-analyst** | Given the Atlas data (rent baseline + supply/demand signals from BPS / QCEW / LAUS), evaluates rental-investment strategies for the area: typical cap rates, what bed/bath count to target, whether the market favors buy-and-hold vs flip. If the user wants property-level cashflow, pause and ask them to provide a specific address (then route to Phase 1A on that). Score: investment upside 0–100. |

Each gets the full Atlas-facts JSON in its prompt plus the user's goal.

## Phase 3 — Synthesis

Combine sub-reports into one verdict.

**Composite score weights:**

Address path (5 sub-scores):
- comps 0.15, cashflow 0.30, neighborhood 0.20, market 0.15, strategy 0.20

Area path (3 sub-scores):
- comps/rent 0.30, area 0.40, strategy 0.30

Adjust if the user said "I'm buying to live in this, not invest" — raise neighborhood/area, drop cashflow/strategy.

**Grade:** A (85+), B (70–84), C (55–69), D (40–54), F (<40).

**Signal:** Strong Buy / Buy / Hold and Watch / Pass / Avoid. Derived from grade + cashflow (or area) score. Cashflow < 40 caps signal at "Hold and Watch" on the address path. Area score < 40 caps signal at "Pass" on the area path.

**For address path:** include a suggested offer range based on cashflow-implied fair value + comp-implied fair value, plus a 5–8 item action checklist for due diligence.

**For area path:** include a target-property profile (bed/bath/type combination most likely to cash-flow given the rent breakdown + HUD FMR + typical area cap rates), plus a 5–8 item area-due-diligence checklist (sublocations to focus on, things to verify in person, sources to follow up).

## Output format

Print a markdown report:

1. **Header**: input identifier (address or area name), input mode (address / area), composite score, grade, signal
2. **Score dashboard**: 5 sub-scores (address) or 3 (area) as a table
3. **Rentometer data**: median, samples, percentile band. Link to `quickview_url` (address path) or the Atlas page (area path).
4. **Sub-agent summaries**: one paragraph per sub-agent with key findings + risks
5. **For address path**: investment scenarios table (buy-and-hold / BRRRR / flip), suggested offer + checklist
6. **For area path**: target-property profile + area-due-diligence checklist
7. **Sources**: deduped URL list. On the area path, this will be much shorter (most data is from Rentometer Atlas, not external scrapes) — that's a feature, not a bug.

## After the markdown report

For the address path, ask if the user wants a Pro PDF report from Rentometer for the same address. If yes, call `/rentometer-report` with the token from Phase 1A.

For the area path, ask if the user wants to drill into specific properties. If yes, route them to providing an address — then start a Phase 1A on that.

## Cost accounting

Tell the user upfront what this will cost:

**Address path:**
- 1 quickview credit (summary) + 1 premium credit (comps) from their wallet
- ~5× sub-agent tool budget on the Claude side (web search)
- A few minutes of wall-clock time

**Area path:**
- 1 quickview credit (atlas/facts), and 0 if /atlas/search finds the slug on the first try (which it usually does)
- ~3× sub-agent tool budget — typically much smaller because no web scraping is needed
- Often under 30 seconds wall-clock

If `$RENTOMETER_API_KEY` is unset, walk the user through `/rentometer-login` before starting Phase 1.

## Why we route this way

Anyone can stitch GreatSchools + city-data + BLS together at runtime — that's what other agentic real-estate tools do, and it's slow and prone to hallucinated comps. Rentometer owns first-party rental data plus an Atlas catalog with curated demographics, FMR, employment, and permits. On the address path we leverage the comp data; on the area path we collapse 90% of the analyst work into a single API call. That's the structural advantage you're trading on every time you run this skill.
