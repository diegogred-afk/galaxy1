#!/bin/bash
# rollback.sh — Revert to a previous version using git revert (safe, no --hard reset)
# Usage: ./scripts/version/rollback.sh

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

echo "================================================"
echo "  Galaxium Travels — Versioning: Rollback"
echo "================================================"
echo ""
echo "⚠️  This uses 'git revert' — it creates a new commit that undoes changes."
echo "    Your history is preserved. Jenkins will redeploy automatically on push."
echo ""

# 1. Check we are on main
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "❌ You are on branch '$CURRENT_BRANCH', not 'main'. Aborting."
    echo "   Switch with: git checkout main"
    exit 1
fi

# 2. Check working tree is clean (no modified, staged, or untracked files)
DIRTY=$(git status --porcelain | grep -v '^??' || true)        # staged or modified
UNTRACKED=$(git status --porcelain | grep '^??' | \
            grep -v '^?? booking_system_backend/\.venv' || true) # untracked (ignore .venv)

if [[ -n "$DIRTY" || -n "$UNTRACKED" ]]; then
    echo "❌ Working tree is not clean. Please commit or stash your changes first."
    echo ""
    if [[ -n "$DIRTY" ]]; then
        echo "   Modified / staged files:"
        echo "$DIRTY" | sed 's/^/     /'
    fi
    if [[ -n "$UNTRACKED" ]]; then
        echo "   Untracked files:"
        echo "$UNTRACKED" | sed 's/^/     /'
    fi
    echo ""
    echo "   Tip: use ./scripts/version/commit.sh to save your changes first."
    exit 1
fi

# 3. Show last 20 commits for selection
echo "📋 Recent versions:"
echo ""
printf "  %-4s  %-8s  %-19s  %s\n" "NUM" "HASH" "DATE" "MESSAGE"
printf "  %-4s  %-8s  %-19s  %s\n" "----" "--------" "-------------------" "-------------------------------------------"

mapfile -t COMMITS < <(git log --max-count=20 --format="%h|%cd|%s" --date=format:"%Y-%m-%d %H:%M:%S")

for i in "${!COMMITS[@]}"; do
    IFS='|' read -r hash date msg <<< "${COMMITS[$i]}"
    printf "  [%-2d] %-8s  %-19s  %s\n" "$((i+1))" "$hash" "$date" "$msg"
done

echo ""
read -rp "Select version number to roll back TO (the commit you want restored): " SELECTION

# Validate selection
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#COMMITS[@]} ]; then
    echo "❌ Invalid selection. Aborting."
    exit 1
fi

TARGET_IDX=$((SELECTION - 1))
IFS='|' read -r TARGET_HASH TARGET_DATE TARGET_MSG <<< "${COMMITS[$TARGET_IDX]}"

if [ "$TARGET_IDX" -eq 0 ]; then
    echo "ℹ️  That is already the current HEAD. Nothing to revert."
    exit 0
fi

echo ""
echo "🎯 You selected:"
echo "   Hash:    $TARGET_HASH"
echo "   Date:    $TARGET_DATE"
echo "   Message: $TARGET_MSG"
echo ""

# 4. Build list of commits to revert (HEAD down to just above target)
REVERT_HASHES=()
for (( i=0; i<TARGET_IDX; i++ )); do
    IFS='|' read -r h _ _ <<< "${COMMITS[$i]}"
    REVERT_HASHES+=("$h")
done

echo "📦 The following commits will be reverted (newest first):"
for h in "${REVERT_HASHES[@]}"; do
    git log -1 --format="   - %h  %s" "$h"
done
echo ""

# 5. Confirm
read -rp "⚠️  Confirm rollback? This will push to galaxy main. [yes/N]: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "❌ Rollback cancelled."
    exit 0
fi

# 6. Revert each commit with --no-commit, then one combined commit
echo ""
echo "⏪ Reverting commits..."

for h in "${REVERT_HASHES[@]}"; do
    git revert --no-edit --no-commit "$h"
done

REVERT_MSG="revert: rollback to $TARGET_HASH ($TARGET_DATE) — $TARGET_MSG"
git commit -m "$REVERT_MSG"

# 7. Push to galaxy main
echo ""
echo "🚀 Pushing rollback to galaxy main..."
git push galaxy main

# 8. Show result
echo ""
echo "✅ Rollback complete! New HEAD:"
git log -1 --format="   Hash:    %H%n   Short:   %h%n   Date:    %cd%n   Message: %s" --date=format:"%Y-%m-%d %H:%M:%S"
echo ""
echo "Jenkins will pick up this push and redeploy automatically."
echo ""
