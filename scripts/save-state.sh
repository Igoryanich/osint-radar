#!/usr/bin/env bash
# Push data/radar.db as a single force-pushed commit on the `state` branch (history never grows).
# Usage (in Actions): scripts/save-state.sh <github-token> <owner/repo>
set -euo pipefail
[ -f data/radar.db ] || exit 0
tmp=$(mktemp -d)
cp data/radar.db "$tmp/"
cd "$tmp"
git init -q -b state
git config user.name "radar-bot"
git config user.email "radar-bot@users.noreply.github.com"
git add -A
git commit -q -m "state $(date -u +%FT%TZ) [skip ci]"
git push -q -f "https://x-access-token:$1@github.com/$2.git" state
rm -rf "$tmp"
