#!/bin/bash
# log.sh — List recent commits (versions) in a readable format
# Usage: ./scripts/version/log.sh [N]
#        N = number of commits to show (default: 20)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

N=${1:-20}

echo "================================================"
echo "  Galaxium Travels — Version History (last $N)"
echo "================================================"
echo ""
printf "%-8s  %-19s  %s\n" "HASH" "DATE" "MESSAGE"
printf "%-8s  %-19s  %s\n" "--------" "-------------------" "-----------------------------------------------"

git log --max-count="$N" \
    --format="%h  %cd  %s" \
    --date=format:"%Y-%m-%d %H:%M:%S"

echo ""
echo "Showing last $N commits. Run:  ./scripts/version/log.sh <N>  for more."
echo ""
