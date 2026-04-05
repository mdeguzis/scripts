#!/usr/bin/env bash
# ============================================================
# scrub-ai-coauthor.sh  (Termux-compatible, no Python needed)
# Rewrites git history to remove AI tool co-author trailers
# and attribution text from commit messages, then optionally
# force-pushes the cleaned history.
#
# USAGE:
#   cd /path/to/your/repo
#   bash scrub-ai-coauthor.sh
# ============================================================

set -euo pipefail

if [ ! -d ".git" ]; then
  echo "ERROR: Not inside a git repository."
  exit 1
fi

REPO_NAME=$(basename "$(pwd)")
echo "=== Scrubbing AI co-author references from: $REPO_NAME ==="
echo ""

# --- Preview ---
echo "Scanning commits for AI references..."
FOUND=0
while IFS= read -r HASH; do
  MSG=$(git log --format='%B' -n1 "$HASH")
  if echo "$MSG" | grep -qiE \
    '(co-authored-by|generated.by|assisted.by|created.with|written.by|authored.by|signed-off-by).*(claude|anthropic|codex|openai|copilot|chatgpt|ai.assistant|cursor|codeium|tabnine|amazon.q|cody)|ai[- ](generated|assisted|written)|llm[- ](generated|assisted)|(powered|made|built|via|using).by.(claude|codex|copilot)'; then
    echo "  MATCH: $(git log --format='%h %s' -n1 "$HASH")"
    FOUND=$((FOUND + 1))
  fi
done < <(git rev-list HEAD)

if [ "$FOUND" -eq 0 ]; then
  echo "No AI co-author references found!"
  exit 0
fi

echo ""
echo "Found $FOUND commit(s) with AI references."
read -rp "Proceed with rewrite? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# --- Clean up any previous filter-branch backups ---
if [ -d ".git/refs/original" ]; then
  echo "Cleaning up previous filter-branch backups..."
  git for-each-ref --format='%(refname)' refs/original/ | while read -r ref; do
    git update-ref -d "$ref"
  done
fi

echo ""
echo "Rewriting commit messages..."

export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch -f --msg-filter '
sed \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Cc]laude/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Aa]nthropic/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Cc]odex/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Oo]pen[Aa][Ii]/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Cc]opilot/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Cc]hat[Gg][Pp][Tt]/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Aa][Ii] [Aa]ssistant/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Cc]ursor/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Cc]odeium/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Tt]abnine/d" \
  -e "/[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]:.*[Cc]ody/d" \
  -e "/[Ss]igned-[Oo]ff-[Bb]y:.*[Cc]laude/d" \
  -e "/[Ss]igned-[Oo]ff-[Bb]y:.*[Aa]nthropic/d" \
  -e "/[Ss]igned-[Oo]ff-[Bb]y:.*[Cc]odex/d" \
  -e "/[Ss]igned-[Oo]ff-[Bb]y:.*[Oo]pen[Aa][Ii]/d" \
  -e "/[Ss]igned-[Oo]ff-[Bb]y:.*[Cc]opilot/d" \
  -e "/[Ss]igned-[Oo]ff-[Bb]y:.*[Cc]hat[Gg][Pp][Tt]/d" \
  -e "/[Aa][Ii]-[Gg]enerated/d" \
  -e "/[Aa][Ii]-[Aa]ssisted/d" \
  -e "/[Aa][Ii] [Gg]enerated/d" \
  -e "/[Aa][Ii] [Aa]ssisted/d" \
  -e "/[Ll][Ll][Mm]-[Gg]enerated/d" \
  -e "/[Ll][Ll][Mm]-[Aa]ssisted/d" \
  -e "/[Gg]enerated.*[Bb]y.*[Cc]laude/d" \
  -e "/[Aa]ssisted.*[Bb]y.*[Cc]laude/d" \
  -e "/[Gg]enerated.*[Bb]y.*[Cc]odex/d" \
  -e "/[Aa]ssisted.*[Bb]y.*[Cc]odex/d" \
  -e "/[Pp]owered by [Cc]laude/d" \
  -e "/[Mm]ade with [Cc]laude/d" \
  -e "/[Bb]uilt with [Cc]laude/d" \
  -e "/[Uu]sing [Cc]laude/d" \
  -e "/[Pp]owered by [Cc]odex/d" \
  -e "/[Mm]ade with [Cc]odex/d" \
  -e "/[Bb]uilt with [Cc]odex/d" \
  -e "/[Uu]sing [Cc]odex/d" \
  -e "/[Pp]owered by [Cc]opilot/d" \
  -e "/[Mm]ade with [Cc]opilot/d" \
  -e "/[Bb]uilt with [Cc]opilot/d" \
  -e "/[Uu]sing [Cc]opilot/d"
' -- --all

echo ""
echo "=== Rewrite complete! ==="
echo ""

# --- Verify cleanup ---
echo "Verifying... checking for any remaining AI references..."
REMAINING=0
while IFS= read -r HASH; do
  MSG=$(git log --format='%B' -n1 "$HASH")
  if echo "$MSG" | grep -qiE \
    '(co-authored-by|generated.by|assisted.by|created.with|written.by|authored.by|signed-off-by).*(claude|anthropic|codex|openai|copilot|chatgpt|ai.assistant|cursor|codeium|tabnine|amazon.q|cody)|ai[- ](generated|assisted|written)|llm[- ](generated|assisted)|(powered|made|built|via|using).by.(claude|codex|copilot)'; then
    REMAINING=$((REMAINING + 1))
  fi
done < <(git rev-list HEAD)

if [ "$REMAINING" -gt 0 ]; then
  echo "WARNING: $REMAINING commit(s) still have AI references."
  echo "You may need to check them manually with: git log --all"
else
  echo "All clean! No AI references remain."
fi

# --- Push ---
echo ""
echo "This will FORCE PUSH rewritten history to all remotes."
echo "This is destructive and cannot be undone on the remote."
echo ""
read -rp "Force push now? (y/N): " PUSH_CONFIRM
if [[ ! "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Skipped push. You can push manually later:"
  echo "  git push --force --all"
  exit 0
fi

echo ""
echo "Fetching latest remote refs..."
git fetch origin

echo "Force pushing..."
git push --force --all

echo ""
echo "=== $REPO_NAME: Done! History scrubbed and pushed. ==="

