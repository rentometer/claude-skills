---
name: rentometer-update
description: Check whether the installed Rentometer Claude Code skills are up to date with the latest published release, and (if not) re-run the installer to pull current skill content. Free — no credit charge. Use when the user asks "are my Rentometer skills current", "update the Rentometer skills", "pull latest skill versions", or you notice a skill's documented behavior doesn't match what the live API returns.
---

# Rentometer Skills — Update

Compares the version of the installed skill package against the latest published release and, if they differ, offers to re-run the installer. The installer is a single curl one-liner; it overwrites the SKILL.md content under `~/.claude/skills/rentometer-*/`. Existing credentials at `~/.config/rentometer/api_key` are not touched.

## Step 1 — Read the versions

```bash
LOCAL_VERSION="$(cat ~/.config/rentometer/skills-version 2>/dev/null | tr -d '[:space:]' || true)"
REMOTE_VERSION="$(curl -fsSL https://raw.githubusercontent.com/rentometer/claude-skills/main/VERSION 2>/dev/null | tr -d '[:space:]' || true)"

echo "Installed: ${LOCAL_VERSION:-unknown}"
echo "Latest:    ${REMOTE_VERSION:-(could not fetch)}"
```

If the remote fetch fails (no network, repo unreachable), tell the user and stop — don't guess at whether an update is needed.

## Step 2 — Compare

- `LOCAL_VERSION == REMOTE_VERSION` → already up to date. Print a one-line confirmation and stop.
- `LOCAL_VERSION` empty / "unknown" → version file was never written (legacy install, predates this skill). Treat as out-of-date and recommend re-install.
- `LOCAL_VERSION != REMOTE_VERSION` → newer (or older) release available; offer to re-install.

## Step 3 — Offer to update

Ask once, with the version delta in the question:

> Installed Rentometer skills are at `<LOCAL>`; latest is `<REMOTE>`. Re-install now? This overwrites `~/.claude/skills/rentometer-*/SKILL.md` with the latest content from GitHub.

If the user says yes:

```bash
curl -fsSL https://raw.githubusercontent.com/rentometer/claude-skills/main/install.sh | bash
```

If no, leave everything as-is and exit.

## Step 4 — Confirm

After the installer finishes, re-read `~/.config/rentometer/skills-version` and tell the user the new version. Mention that any open Claude Code sessions need to be restarted to pick up new or renamed skills (existing skill content is re-read each invocation, but the slash-command list is cached at session start).

## Notes

- API credentials (`~/.config/rentometer/api_key`) and the `RENTOMETER_API_KEY` env var are independent of skill content and are not touched by the installer.
- This skill itself only updates after a re-install — so the *next* improvement to `/rentometer-update` takes one extra run to land.
- The version file lives at `~/.config/rentometer/skills-version`. It's a flat text file containing just the version string.
