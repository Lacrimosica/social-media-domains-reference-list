#!/usr/bin/env bash
# Rebuilds master-blocklist.txt from all platform files in lists/.
# Platform files are auto-detected — just drop a .txt into lists/ and it's included.
#
# Usage:
#   ./build.sh              — interactive: shows ignore summary, prompts before building
#   ./build.sh --no-ignore  — skips .buildignore entirely and builds everything

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LISTS_DIR="$REPO_DIR/lists"
OUTPUT="$REPO_DIR/master-blocklist.txt"
IGNORE_FILE="$REPO_DIR/.buildignore"
DATE="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# ── Auto-detect platform files (sorted) ──────────────────────────────────────
mapfile -t ALL_FILES < <(find "$LISTS_DIR" -maxdepth 1 -name "*.txt" | sort)
mapfile -t ALL_NAMES < <(for f in "${ALL_FILES[@]}"; do basename "$f" .txt; done)

# ── Flags ─────────────────────────────────────────────────────────────────────
SKIP_IGNORE=false
for arg in "$@"; do
  [[ "$arg" == "--no-ignore" ]] && SKIP_IGNORE=true
done

# ── Ignore file ───────────────────────────────────────────────────────────────
if [[ ! -f "$IGNORE_FILE" ]]; then
  cat > "$IGNORE_FILE" << 'EOF'
# .buildignore — platform files to exclude from master-blocklist.txt
# One filename per line (with or without .txt). Lines starting with # are comments.
#
# Examples:
#   whatsapp
#   telegram
#   medium.txt
EOF
  echo "Created $IGNORE_FILE (empty — no files ignored)"
fi

# Read ignored names, strip .txt suffix for normalised comparison
mapfile -t IGNORED_RAW < <(grep -vE '^\s*(#|$)' "$IGNORE_FILE" 2>/dev/null || true)
IGNORED=()
for entry in "${IGNORED_RAW[@]}"; do
  IGNORED+=("$(basename "$entry" .txt)")
done

# ── Helper: check if a platform name is ignored ───────────────────────────────
is_ignored() {
  local name="$1"
  for ig in "${IGNORED[@]}"; do
    [[ "$ig" == "$name" ]] && return 0
  done
  return 1
}

# ── Ignore summary + prompt ───────────────────────────────────────────────────
if [[ "$SKIP_IGNORE" == false ]]; then
  echo ""
  if [[ ${#IGNORED[@]} -gt 0 ]]; then
    echo "── .buildignore: the following platform files will be skipped ──"
    echo ""
    for name in "${IGNORED[@]}"; do
      if [[ -f "$LISTS_DIR/${name}.txt" ]]; then
        printf "  ✕  %s.txt\n" "$name"
      else
        printf "  ?  %s.txt  (file not found in lists/)\n" "$name"
      fi
    done
  else
    echo "── .buildignore is empty — all platform files will be included ──"
  fi

  echo ""
  echo "  [1] Build with ignore list applied  (default)"
  echo "  [2] Open .buildignore to edit, then re-run"
  echo "  [3] Build everything — override ignore list this time"
  echo ""
  read -rp "Choice [1/2/3]: " choice

  case "$choice" in
    2)
      "${EDITOR:-vi}" "$IGNORE_FILE"
      echo "Re-run ./build.sh when ready."
      exit 0
      ;;
    3)
      SKIP_IGNORE=true
      echo ""
      echo "Overriding ignore list — building all platform files."
      ;;
    *)
      echo ""
      if [[ ${#IGNORED[@]} -gt 0 ]]; then
        echo "Skipping: ${IGNORED[*]}"
      fi
      ;;
  esac
fi

# ── Count total entries ───────────────────────────────────────────────────────
TOTAL=0
for name in "${ALL_NAMES[@]}"; do
  [[ "$SKIP_IGNORE" == false ]] && is_ignored "$name" && continue
  file="$LISTS_DIR/${name}.txt"
  count=$(grep -cvE '^\s*(#|$)' "$file" || true)
  TOTAL=$((TOTAL + count))
done

# ── Build platform list for header (active platforms only) ───────────────────
ACTIVE_LABELS=()
declare -A PLATFORM_LABELS=(
  [youtube]="YouTube (Google/Alphabet)"
  [tiktok]="TikTok (ByteDance)"
  [instagram]="Instagram (Meta Platforms)"
  [facebook]="Facebook (Meta Platforms)"
  [twitter]="X / Twitter"
  [reddit]="Reddit"
  [linkedin]="LinkedIn (Microsoft)"
  [pinterest]="Pinterest"
  [snapchat]="Snapchat (Snap Inc.)"
  [discord]="Discord"
  [twitch]="Twitch (Amazon)"
  [vimeo]="Vimeo"
  [mastodon]="Mastodon"
  [medium]="Medium"
  [whatsapp]="WhatsApp (Meta Platforms)"
  [telegram]="Telegram"
)
for name in "${ALL_NAMES[@]}"; do
  [[ "$SKIP_IGNORE" == false ]] && is_ignored "$name" && continue
  label="${PLATFORM_LABELS[$name]:-$name}"
  ACTIVE_LABELS+=("$label")
done

# Build comma-separated description string
PLATFORM_DESC=$(IFS=', '; echo "${ACTIVE_LABELS[*]}")

# ── Write header ──────────────────────────────────────────────────────────────
cat > "$OUTPUT" << EOF
# Title: Social Media Master Blocklist
# Description: Domains owned and operated by: ${PLATFORM_DESC}
# Homepage: https://github.com/Lacrimosica/social-media-domains-reference-list
# License: GNU GPLv3
# Last modified: ${DATE}
# Format: hosts
# Entries: ${TOTAL}
# URL: https://raw.githubusercontent.com/Lacrimosica/social-media-domains-reference-list/main/master-blocklist.txt
#
# This list contains domain names owned and operated by:
EOF
for label in "${ACTIVE_LABELS[@]}"; do
  echo "# - ${label}" >> "$OUTPUT"
done

# ── Append platform sections ──────────────────────────────────────────────────
for name in "${ALL_NAMES[@]}"; do
  [[ "$SKIP_IGNORE" == false ]] && is_ignored "$name" && continue
  file="$LISTS_DIR/${name}.txt"
  printf '\n#\n# %s DOMAINS\n#\n' "${name^^}" >> "$OUTPUT"
  grep -vE '^\s*(#|$)' "$file" >> "$OUTPUT" || true
done

echo ""
echo "Built $OUTPUT — $TOTAL entries from ${#ACTIVE_LABELS[@]} platform(s)"
