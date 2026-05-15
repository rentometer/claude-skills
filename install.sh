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
  rentometer-area
  rentometer-area-search
  rentometer-quota
  rentometer-analyze
)

echo "Installing Rentometer Claude Code skills into $DEST"
mkdir -p "$DEST"

# If we're running from a local clone, copy from disk. Otherwise pull each
# SKILL.md from the raw GitHub URL.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/skills" ]]; then
  echo "  source: local clone ($SCRIPT_DIR/skills)"
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$DEST/$skill"
    cp "$SCRIPT_DIR/skills/$skill/SKILL.md" "$DEST/$skill/SKILL.md"
    echo "    installed: $skill"
  done
else
  echo "  source: $SKILLS_REPO_RAW"
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$DEST/$skill"
    curl -fsSL "$SKILLS_REPO_RAW/skills/$skill/SKILL.md" -o "$DEST/$skill/SKILL.md"
    echo "    installed: $skill"
  done
fi

echo
echo "Done. ${#SKILLS[@]} skills installed."
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
The free /rentometer-area and /rentometer-area-search skills work
without a key.
EOF
fi
