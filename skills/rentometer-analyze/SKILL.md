---
name: rentometer-analyze
description: Run a full multi-agent investment analysis on a rental property — pulls real comps from Rentometer (first-party data), then fans out to parallel sub-agents for neighborhood, cash-flow, market-conditions, and investment-strategy analysis, then synthesizes into a graded report. The flagship Rentometer skill. Costs ~2 quickview + 1 premium credit per address. Use when the user asks for a "full analysis", "investment analysis", "should I buy [address]", or pastes a listing.
---

# Rentometer Full Property Analysis

The flagship skill. Other Claude Code real-estate skills scrape Zillow/Redfin at runtime — this one runs Rentometer's first-party rent data as the trusted backbone and uses Claude only for the analysis layer. Faster, cheaper, less hallucination.

## Pipeline

Three phases. Run them in order. **Phase 2's sub-agents run in parallel** — dispatch them all in a single message.

### Phase 1 — Anchor on real data (Rentometer API)

Get the ground-truth rent data and comps for the address. Do this synchronously.

1. Ask the user for the address (and bed/bath if not implied by a listing they paste). Geocode handled server-side.
2. Run `/rentometer-summary` for the address. Capture the response and the `token`.
3. Run `/rentometer-comps` with the token. Capture the list of comps.

Stop if `samples < 5` and surface the data-thinness to the user before continuing — the analysis won't be reliable.

### Phase 2 — Parallel sub-agent fan-out

Dispatch five sub-agents *in parallel* (single message with five Agent tool calls). Each gets the Phase 1 data (summary + comps + address) in its prompt and returns a scored sub-report.

| Sub-agent | What it produces |
|---|---|
| **comps-analyst** | Reviews the comps from Phase 1. Identifies outliers, sample quality, distance distribution. Estimates fair-market rent with a confidence band. Score: comp quality 0–100. |
| **cashflow-analyst** | Asks user (or estimates) purchase price, down payment %, interest rate, taxes, insurance, HOA, vacancy %, mgmt %. Computes monthly + annual cash flow, cap rate, cash-on-cash return, GRM, DSCR. Score: income potential 0–100. |
| **neighborhood-analyst** | Web-searches for: school ratings (GreatSchools), crime stats (city-data, FBI UCR), walkability (WalkScore), demographics (Census), recent growth/development. Score: neighborhood quality 0–100. |
| **market-analyst** | Web-searches for local market signals: months of supply, list-to-sale ratio, days on market, year-over-year price/rent change, new construction permits. Determines buyer's vs seller's market. Score: market conditions 0–100. |
| **strategy-analyst** | Given the rent (Phase 1), estimated price (user-provided or web-research), and the other agents' inputs once they return, evaluates buy-and-hold, BRRRR, and fix-and-flip scenarios. Computes 5/10-year appreciation projections in bull/base/bear cases. Score: investment upside 0–100. The strategy agent depends on the others — dispatch it last or roll its work into Phase 3. |

Each sub-agent's prompt should include:
- The full Phase 1 summary + comps JSON
- The user's stated goal (rental investment vs primary residence vs flip)
- "Return a JSON object with `score`, `signal`, `key_findings` (3–5 bullets), `risks` (2–3 bullets), and `sources` (URLs you cited)"

### Phase 3 — Synthesis

Combine the five sub-reports into one verdict:

1. Composite score = weighted average. Default weights: comps 0.15, cashflow 0.30, neighborhood 0.20, market 0.15, strategy 0.20. Adjust if the user said "I'm buying to live in this, not invest" (raise neighborhood, drop cashflow/strategy).
2. Grade: A (85+), B (70–84), C (55–69), D (40–54), F (<40).
3. Signal: `Strong Buy` / `Buy` / `Hold and Watch` / `Pass` / `Avoid` — derived from grade plus the cashflow score (cashflow < 40 caps the signal at "Hold and Watch" regardless of overall grade).
4. Suggested offer range based on cashflow analysis + comp-implied fair value.
5. Action checklist: 5–8 concrete things to verify before making an offer.

## Output format

Print a markdown report with sections in this order:

1. **Header**: address, beds/baths, listing price (if given), composite score, grade, signal
2. **Score dashboard**: the five sub-scores as a table
3. **Rentometer comp data** (Phase 1): median rent, sample size, percentile band, link to `quickview_url`
4. **Sub-agent summaries**: one paragraph per sub-agent with their key findings and risks
5. **Investment scenarios**: buy-and-hold / BRRRR / flip table with NPV or cash-on-cash
6. **Suggested offer + checklist**
7. **Sources**: deduped URL list from all sub-agents

## After the markdown report

Ask the user if they want a Pro PDF report from Rentometer for the same address. If yes, call `/rentometer-report` with the token from Phase 1.

## Cost accounting

Tell the user upfront what this will cost:
- 1 quickview credit (summary) + 1 premium credit (comps) from their Rentometer wallet
- ~5× sub-agent tool budget on the Claude side (web search, etc.)
- A few minutes of wall-clock time

If `$RENTOMETER_API_KEY` is unset, walk them through getting one before starting Phase 1.
