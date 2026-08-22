#!/usr/bin/env bash
# ============================================================
#  sync-agents.sh — check agents/ personas against upstream
#  https://github.com/msitarzewski/agency-agents
#
#  This repo vendors a curated subset of agency-agents' persona
#  files (see agents/UPSTREAM.manifest.tsv for the local->upstream
#  path mapping and the sha256 recorded at last sync). This script
#  never adds or removes vendored files on its own — that stays a
#  manual curation decision (README, SKILL.md, and install.sh all
#  hand-maintain the vendored set) — it only reports drift and,
#  with --apply, refreshes files that have NOT been locally edited
#  since the last sync.
#
#  Usage:
#    scripts/sync-agents.sh                 # report only (default)
#    scripts/sync-agents.sh --apply         # write refreshed upstream content
#    scripts/sync-agents.sh --repo-dir DIR  # use an existing local clone
#                                            # instead of cloning a fresh one
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_DIR/agents/UPSTREAM.manifest.tsv"
UPSTREAM_URL="https://github.com/msitarzewski/agency-agents.git"
APPLY=false
UPSTREAM_DIR=""
CLEANUP_UPSTREAM=false

for arg in "$@"; do
  case $arg in
    --apply) APPLY=true ;;
    --repo-dir=*) UPSTREAM_DIR="${arg#--repo-dir=}" ;;
    --repo-dir) shift; UPSTREAM_DIR="${1:-}" ;;
  esac
done

info()    { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
changed() { echo -e "\033[0;35m[DIFF]\033[0m  $*"; }

if [ ! -f "$MANIFEST" ]; then
  echo "Manifest not found: $MANIFEST" >&2
  exit 1
fi

# ── Get an upstream checkout ────────────────────────────────
if [ -z "$UPSTREAM_DIR" ]; then
  UPSTREAM_DIR="$(mktemp -d)"
  CLEANUP_UPSTREAM=true
  info "Cloning $UPSTREAM_URL (shallow)…"
  git clone --depth 1 -q "$UPSTREAM_URL" "$UPSTREAM_DIR"
fi
trap '[ "$CLEANUP_UPSTREAM" = true ] && rm -rf "$UPSTREAM_DIR"' EXIT

UPSTREAM_SHA="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
info "Comparing against upstream commit $UPSTREAM_SHA"

# ── Walk the manifest ───────────────────────────────────────
CHANGED=0
LOCALLY_MODIFIED=0
REMOVED_UPSTREAM=0
UNCHANGED=0
NEW_MANIFEST_LINES=()

while IFS=$'\t' read -r local_path upstream_path local_sha256; do
  [ -z "$local_path" ] && continue
  case "$local_path" in \#*) continue ;; esac

  local_file="$REPO_DIR/$local_path"
  upstream_file="$UPSTREAM_DIR/$upstream_path"

  if [ ! -f "$upstream_file" ]; then
    warn "Removed upstream (no longer at $upstream_path): $local_path"
    REMOVED_UPSTREAM=$((REMOVED_UPSTREAM + 1))
    NEW_MANIFEST_LINES+=("$local_path"$'\t'"$upstream_path"$'\t'"$local_sha256")
    continue
  fi

  current_local_sha256="$(sha256sum "$local_file" | awk '{print $1}')"
  new_upstream_sha256="$(sha256sum "$upstream_file" | awk '{print $1}')"

  if [ "$new_upstream_sha256" = "$current_local_sha256" ]; then
    UNCHANGED=$((UNCHANGED + 1))
    NEW_MANIFEST_LINES+=("$local_path"$'\t'"$upstream_path"$'\t'"$current_local_sha256")
    continue
  fi

  if [ "$current_local_sha256" != "$local_sha256" ]; then
    # Local file has drifted from what we last synced — it was hand-edited.
    # Never clobber that silently, with or without --apply.
    warn "Locally modified, NOT touching (upstream also changed): $local_path"
    LOCALLY_MODIFIED=$((LOCALLY_MODIFIED + 1))
    NEW_MANIFEST_LINES+=("$local_path"$'\t'"$upstream_path"$'\t'"$local_sha256")
    continue
  fi

  changed "Upstream changed: $local_path"
  CHANGED=$((CHANGED + 1))
  if $APPLY; then
    cp "$upstream_file" "$local_file"
    NEW_MANIFEST_LINES+=("$local_path"$'\t'"$upstream_path"$'\t'"$new_upstream_sha256")
  else
    NEW_MANIFEST_LINES+=("$local_path"$'\t'"$upstream_path"$'\t'"$local_sha256")
  fi
done < <(tail -n +2 "$MANIFEST")

if $APPLY; then
  {
    echo -e "# local_path\tupstream_path\tlocal_sha256"
    printf '%s\n' "${NEW_MANIFEST_LINES[@]}"
  } > "$MANIFEST"
fi

# ── Report new upstream files in divisions we already vendor from ──
info "Scanning for new upstream agents in vendored divisions (engineering, design, product, marketing)…"
NEW_COUNT=0
for division in engineering design product marketing; do
  [ -d "$UPSTREAM_DIR/$division" ] || continue
  while IFS= read -r -d '' f; do
    rel="$division/$(basename "$f")"
    if ! grep -qF $'\t'"$rel"$'\t' "$MANIFEST"; then
      echo "  new upstream, not vendored: $rel"
      NEW_COUNT=$((NEW_COUNT + 1))
    fi
  done < <(find "$UPSTREAM_DIR/$division" -maxdepth 1 -name '*.md' -print0)
done
[ "$NEW_COUNT" -eq 0 ] && info "No new agents in vendored divisions."

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────"
echo "  Sync report — agency-agents @ $UPSTREAM_SHA"
echo "────────────────────────────────────────────────────────"
echo "  Unchanged:              $UNCHANGED"
echo "  Changed upstream:       $CHANGED  $($APPLY && echo '(applied)' || echo '(dry run — rerun with --apply to write)')"
echo "  Locally modified:       $LOCALLY_MODIFIED  (skipped — hand-edited, never auto-overwritten)"
echo "  Removed upstream:       $REMOVED_UPSTREAM  (kept locally — remove manually if desired)"
echo "  New upstream, unvendored: $NEW_COUNT  (manual curation decision — not auto-added)"
echo ""

if [ "$CHANGED" -gt 0 ] && ! $APPLY; then
  warn "Rerun with --apply to write the $CHANGED changed file(s) to disk."
fi
if [ "$CHANGED" -gt 0 ] && $APPLY; then
  success "$CHANGED file(s) updated. Update NOTICE.md's synced commit SHA to $UPSTREAM_SHA,"
  warn "and re-check README.md / SKILL.md §6.3 tables if file counts or descriptions changed."
fi

exit 0
