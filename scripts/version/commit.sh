#!/bin/bash
# commit.sh — Stage selected files, commit with a message, push to galaxy main
# Usage: ./scripts/version/commit.sh

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

echo "================================================"
echo "  Galaxium Travels — Versioning: Commit & Push"
echo "================================================"
echo ""

# 1. Check we are on main
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "❌ You are on branch '$CURRENT_BRANCH', not 'main'. Aborting."
    echo "   Switch with: git checkout main"
    exit 1
fi

# 2. Check for already-staged files and abort if any exist
STAGED=$(git diff --cached --name-only)
if [[ -n "$STAGED" ]]; then
    echo "❌ There are already staged files. Aborting to avoid mixing staged content."
    echo ""
    echo "   Staged files:"
    git diff --cached --name-only | sed 's/^/     - /'
    echo ""
    echo "   Please unstage them first with: git restore --staged <file>"
    exit 1
fi

# 3. Show current status
echo "📋 Current git status:"
echo ""
git status --short
echo ""

# 4. List modified/untracked files for selection (exclude .venv)
mapfile -t FILES < <(git status --short | grep -v '^\s*$' | awk '{print $2}' | grep -v '^booking_system_backend/\.venv')

if [ ${#FILES[@]} -eq 0 ]; then
    echo "✅ Nothing to commit. Working tree is clean."
    exit 0
fi

echo "📁 Files available to stage (select by number, space-separated, or 'a' for all):"
echo ""
for i in "${!FILES[@]}"; do
    printf "  [%d] %s\n" "$((i+1))" "${FILES[$i]}"
done
echo ""
read -rp "Your selection: " SELECTION

SELECTED=()
if [[ "$SELECTION" == "a" || "$SELECTION" == "A" ]]; then
    SELECTED=("${FILES[@]}")
else
    for num in $SELECTION; do
        idx=$((num - 1))
        if [[ $idx -ge 0 && $idx -lt ${#FILES[@]} ]]; then
            SELECTED+=("${FILES[$idx]}")
        else
            echo "⚠️  Invalid selection: $num — skipped"
        fi
    done
fi

if [ ${#SELECTED[@]} -eq 0 ]; then
    echo "❌ No valid files selected. Aborting."
    exit 1
fi

echo ""
echo "📦 Files to be staged:"
for f in "${SELECTED[@]}"; do
    echo "   + $f"
done
echo ""

# 5. Ask for commit message
read -rp "📝 Commit message (version description): " MSG
if [[ -z "$MSG" ]]; then
    echo "❌ Commit message cannot be empty. Aborting."
    exit 1
fi

# 6. Stage selected files
for f in "${SELECTED[@]}"; do
    git add -- "$f"
done

# 7. Commit
git commit -m "$MSG"

# 8. Push to galaxy main
echo ""
echo "🚀 Pushing to galaxy main..."
git push galaxy main

# 9. Show new commit hash
echo ""
echo "✅ Done! New commit:"
git log -1 --format="   Hash:    %H%n   Short:   %h%n   Date:    %cd%n   Message: %s" --date=format:"%Y-%m-%d %H:%M:%S"
echo ""
