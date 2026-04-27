#!/usr/bin/env bash
# Unleash uninstall — manifest-driven removal of every change Unleash made.
# Usage: unleash-uninstall.sh [--since <commit-sha>] [--yes]
#   --since <sha>   only revert entries committed after the given SHA
#   --yes           skip per-file confirmation (use with care)

set -euo pipefail

PROJECT_ROOT="$(pwd)"
MANIFEST="$PROJECT_ROOT/.unleash/manifest.json"
SINCE_SHA=""
ASSUME_YES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE_SHA="$2"; shift 2 ;;
    --yes) ASSUME_YES="true"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "no manifest at $MANIFEST — nothing to uninstall" >&2
  exit 0
fi

confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" == "true" ]]; then return 0; fi
  read -p "$prompt [y/N]: " yn
  [[ "$yn" =~ ^[Yy]$ ]]
}

# Use jq to enumerate created entries (only those AT OR AFTER --since if specified)
# Portable read-into-array pattern (works on bash 3.2+, including macOS default /bin/bash)
CREATED=()
while IFS= read -r line; do
  [[ -n "$line" ]] && CREATED+=("$line")
done < <(jq -r --arg since "$SINCE_SHA" '
  .created[] | select($since == "" or .commit_sha != $since)
  | "\(.path)\t\(.commit_sha)"
' "$MANIFEST")

MODIFIED=()
while IFS= read -r line; do
  [[ -n "$line" ]] && MODIFIED+=("$line")
done < <(jq -r --arg since "$SINCE_SHA" '
  .modified[] | select($since == "" or .commit_sha != $since)
  | "\(.path)\t\(.original_sha)\t\(.block_marker)\t\(.commit_sha)"
' "$MANIFEST")

echo "Unleash uninstall — review pending changes:"
echo "  ${#CREATED[@]} files to remove"
echo "  ${#MODIFIED[@]} files to revert"
[[ "$SINCE_SHA" != "" ]] && echo "  filtered to entries since $SINCE_SHA"
echo ""

# Remove created files
for line in "${CREATED[@]}"; do
  IFS=$'\t' read -r path commit_sha <<< "$line"
  full="$PROJECT_ROOT/$path"
  if [[ ! -e "$full" ]]; then
    echo "skip (not present): $path"
    continue
  fi
  if confirm "remove $path?"; then
    rm -rf "$full"
    echo "removed: $path"
  else
    echo "kept: $path"
  fi
done

# Revert modified files
for line in "${MODIFIED[@]}"; do
  IFS=$'\t' read -r path original_sha block_marker commit_sha <<< "$line"
  full="$PROJECT_ROOT/$path"
  if [[ ! -f "$full" ]]; then
    echo "skip (not present): $path"
    continue
  fi
  current_sha="$(git hash-object "$full")"
  if [[ "$current_sha" != "$original_sha" ]] && [[ -n "$original_sha" ]]; then
    echo "WARN: $path has been modified outside Unleash since install"
    echo "      manifest original_sha: $original_sha"
    echo "      current sha:           $current_sha"
    if ! confirm "revert anyway? (your hand edits will be lost)"; then
      echo "kept: $path"
      continue
    fi
  fi
  if [[ -z "$block_marker" ]]; then
    echo "skip (no block_marker recorded): $path"
    continue
  fi
  if confirm "revert $path?"; then
    # block_marker is "<start> ... <end>" — split on " ... "
    start_marker="${block_marker% ... *}"
    end_marker="${block_marker#* ... }"
    # Use sed to delete lines from start_marker to end_marker (inclusive)
    sed -i.unleash-bak "/${start_marker}/,/${end_marker}/d" "$full"
    rm -f "${full}.unleash-bak"
    echo "reverted: $path (block removed)"
  else
    echo "kept: $path"
  fi
done

# Remove manifest itself if no --since filter (full uninstall)
if [[ "$SINCE_SHA" == "" ]] && confirm "remove .unleash/manifest.json itself?"; then
  rm -f "$MANIFEST"
  # Try to remove .unleash/ if empty
  rmdir "$PROJECT_ROOT/.unleash" 2>/dev/null || true
  echo "removed manifest"
fi

echo ""
echo "Uninstall complete. Review with: git status"
