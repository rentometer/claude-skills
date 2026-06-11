#!/usr/bin/env bash
# Install Rentometer skills into ~/.claude/skills/
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rentometer/claude-skills/main/install.sh | bash
#
# Or, from a local clone:
#   ./install.sh

set -euo pipefail

SKILLS_REPO_RAW="https://raw.githubusercontent.com/rentometer/claude-skills/main"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

SKILLS=(
  rentometer-login
  rentometer-summary
  rentometer-comps
  rentometer-batch
  rentometer-property-rents
  rentometer-report
  rentometer-atlas-search
  rentometer-atlas-facts
  rentometer-metrics
  rentometer-rankings
  rentometer-quota
  rentometer-quick-analysis
  rentometer-deep-analysis
  rentometer-update
)

# Skills removed in past releases. Re-running the installer should delete these
# stale copies so /rentometer-update users don't keep a dead skill around.
# (rentometer-analyze was split into quick-analysis + deep-analysis in 1.3.0.)
RETIRED_SKILLS=(
  rentometer-analyze
)

VERSION_FILE="$HOME/.config/rentometer/skills-version"

echo "Installing Rentometer Claude Code skills into $DEST"
mkdir -p "$DEST"

# If we're running from a local clone, copy from disk. Otherwise pull each
# SKILL.md from the raw GitHub URL.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

mkdir -p "$(dirname "$VERSION_FILE")"

if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/skills" ]]; then
  echo "  source: local clone ($SCRIPT_DIR/skills)"
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$DEST/$skill"
    cp "$SCRIPT_DIR/skills/$skill/SKILL.md" "$DEST/$skill/SKILL.md"
    echo "    installed: $skill"
  done
  if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
    cp "$SCRIPT_DIR/VERSION" "$VERSION_FILE"
  fi
else
  echo "  source: $SKILLS_REPO_RAW"
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$DEST/$skill"
    curl -fsSL "$SKILLS_REPO_RAW/skills/$skill/SKILL.md" -o "$DEST/$skill/SKILL.md"
    echo "    installed: $skill"
  done
  curl -fsSL "$SKILLS_REPO_RAW/VERSION" -o "$VERSION_FILE" 2>/dev/null || true
fi

# Remove any retired skills left over from older installs.
for skill in "${RETIRED_SKILLS[@]}"; do
  if [[ -d "$DEST/$skill" ]]; then
    rm -rf "$DEST/$skill"
    echo "    removed (retired): $skill"
  fi
done

INSTALLED_VERSION="$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]' || echo "unknown")"

echo
echo "Done. ${#SKILLS[@]} skills installed (version: ${INSTALLED_VERSION:-unknown})."
echo

CRED_FILE="$HOME/.config/rentometer/api_key"
if [[ -n "${RENTOMETER_API_KEY:-}" ]]; then
  echo "RENTOMETER_API_KEY is set in your environment — you're ready to go."
  echo "Try: /rentometer-summary <address>"
elif [[ -s "$CRED_FILE" ]]; then
  echo "Saved credential found at $CRED_FILE — you're ready to go."
  echo "Try: /rentometer-quota to confirm, or /rentometer-summary <address>."
else
  cat <<'EOF'
Next step — authenticate. Inside Claude Code, run:

  /rentometer-login

That'll walk you through generating an API key and saving it locally.
EOF
fi
