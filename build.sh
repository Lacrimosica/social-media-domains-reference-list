#!/usr/bin/env bash
# Rebuilds list.txt from all individual platform files.
# Usage: ./build.sh
# Edit a platform file, then run this script — list.txt is updated automatically.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$REPO_DIR/list.txt"
DATE="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Order of platforms in the master list
PLATFORMS=(
  youtube
  tiktok
  instagram
  facebook
  twitter
  reddit
  linkedin
  pinterest
  snapchat
  discord
  twitch
  vimeo
  mastodon
  medium
)

# Count total domain entries across all platform files
TOTAL=0
for platform in "${PLATFORMS[@]}"; do
  file="$REPO_DIR/${platform}.txt"
  if [[ -f "$file" ]]; then
    count=$(grep -c "^0\.0\.0\.0" "$file" || true)
    TOTAL=$((TOTAL + count))
  fi
done

# Write master list header
cat > "$OUTPUT" << EOF
# Title: Social Media Domains Reference List
# Description: Comprehensive list of domains owned and operated by major social media platforms (YouTube, TikTok, Instagram, Facebook/Meta, X/Twitter, Reddit, LinkedIn, Pinterest, Snapchat, Discord, Twitch, Vimeo, Mastodon, Medium)
# Homepage: https://github.com/Lacrimosica/social-media-domains-reference-list
# License: GNU GPLv3
# Last modified: ${DATE}
# Format: hosts
# Entries: ${TOTAL}
# URL: https://raw.githubusercontent.com/Lacrimosica/social-media-domains-reference-list/main/list.txt
#
# This list contains domain names owned and operated by:
# - YouTube (Google/Alphabet)
# - TikTok (ByteDance)
# - Instagram (Meta Platforms)
# - Facebook (Meta Platforms)
# - X / Twitter
# - Reddit
# - LinkedIn
# - Pinterest
# - Snapchat
# - Discord
# - Twitch (Amazon)
# - Vimeo
# - Mastodon
# - Medium
EOF

# Append each platform's domains (skip header lines from individual files)
for platform in "${PLATFORMS[@]}"; do
  file="$REPO_DIR/${platform}.txt"
  if [[ ! -f "$file" ]]; then
    echo "Warning: $file not found, skipping" >&2
    continue
  fi
  # Derive section label from filename
  label="${platform^^} DOMAINS"
  printf '\n#\n# %s\n#\n' "$label" >> "$OUTPUT"
  grep "^0\.0\.0\.0" "$file" >> "$OUTPUT"
done

echo "Built $OUTPUT — $TOTAL entries across ${#PLATFORMS[@]} platforms"
