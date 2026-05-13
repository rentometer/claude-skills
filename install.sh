#!/usr/bin/env bash
# Install Rentometer skills into ~/.claude/skills/
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rentometer/rentometer2/main/claude-skills/install.sh | bash
#
# Or, from a local clone:
#   ./claude-skills/install.sh

set -euo pipefail

SKILLS_REPO_RAW="https://raw.githubusercontent.com/rentometer/rentometer2/main/claude-skills"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

SKILLS=(
  rentometer-summary
  rentometer-comps
  rentometer-batch
  rentometer-property-rents
  rentometer-report
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
if [[ -z "${RENTOMETER_API_KEY:-}" ]]; then
  cat <<EOF
Next step — set your API key:

  1. Generate one at https://www.rentometer.com/rentometer-api/settings
  2. export RENTOMETER_API_KEY=your_key_here
  3. (optional) add the export to ~/.zshrc or ~/.bashrc to persist

The free /rentometer-area and /rentometer-area-search skills work without a key.
EOF
else
  echo "RENTOMETER_API_KEY is set — you're ready to go. Try: /rentometer-summary"
fi
