#!/usr/bin/env bash
# ============================================================
#  propose-correction-pr.sh — Self-Improvement Loop
#
#  Turns one distilled human correction into a durable, git-controlled
#  artifact: an append to corrections/LEDGER.md, and — when the rule is
#  worth changing future behavior for (--status promote) — a TARGETED
#  patch into the orchestrator's own skill files, shipped as a single
#  reviewable PR.
#
#  Design:
#   - Thin interface: one script, one job. All git/worktree/PR plumbing
#     is internal (deep module); the ledger file is the only seam.
#   - Placement is the CALLER's job, not this script's: decide the most
#     relevant existing section/table/checklist for the rule yourself
#     (see skills/manhattan-orchestrator/SELF_IMPROVEMENT.md § Placement
#     duty) and pass --target-file/--anchor/--patch-file accordingly.
#     This script only guarantees the text lands exactly where asked,
#     reliably and reviewably — it does not choose where.
#   - Never touches your current checkout: does its work in an isolated
#     `git worktree` off origin/<base-branch>.
#   - Degrades gracefully with no `gh` CLI / no GitHub token: falls back
#     to printing a ready-to-click compare URL instead of failing.
#
#  Usage:
#    scripts/propose-correction-pr.sh \
#      --id CORR-2026-08-14-001 \
#      --status candidate|promote \
#      --title "Short summary for the PR/commit" \
#      --trigger-phase "Phase 3: Delegate" \
#      --task-type "frontend-only-implementation" \
#      --agent-behavior "Introduced a database dependency despite the task constraint." \
#      --human-correction "Keep the implementation entirely frontend-side and lightweight." \
#      --rule "Do not introduce persistence infrastructure unless explicitly required." \
#      --applies-when "User requests a lightweight implementation" \
#      --applies-when "Existing behavior can be implemented in local/frontend state" \
#      --exceptions "Explicit persistence requirement" \
#      --session-id "<session id>" \
#      --occurrence-count 1 \
#      --confidence 0.8 \
#      [--target-file "skills/manhattan-orchestrator/SKILL.md"] \
#      [--anchor "### 5.1 Architecture Acceptance Checklist"] \
#      [--patch-file /path/to/hand-authored-concise-markdown-block.md] \
#      [--review-notes "What a human reviewer should double-check"] \
#      [--tests-performed "How this was verified (e.g. rubric self-score, dry-run)"] \
#      [--dry-run]
#
#  Flags may repeat (--applies-when, --exceptions) to add multiple bullets.
#
#  --target-file defaults to skills/manhattan-orchestrator/LEARNED_CONSTRAINTS.md
#  (the fallback home) — pass an --anchor within SKILL.md itself (or any other
#  file) to place the rule as a targeted patch inside an existing section
#  instead. Without --patch-file, a single concise bullet (`- **[ID]** <rule>`)
#  is inserted at the anchor (or appended to the target file if no anchor is
#  given); with --patch-file, its exact content is inserted instead — use this
#  for a table row, a tightened existing bullet, or a short diagram so the
#  patch matches the surrounding document's tone instead of always being a
#  new prose paragraph.
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_TARGET_FILE_REL="skills/manhattan-orchestrator/LEARNED_CONSTRAINTS.md"
DEFAULT_ANCHOR="Empty until the first correction is promoted here"
BASE_BRANCH="main"
STATUS="candidate"
CONFIDENCE="0.6"
OCCURRENCE_COUNT="1"
DRY_RUN=false
APPLIES_WHEN=()
EXCEPTIONS=()
TARGET_FILE_REL=""
ANCHOR=""
PATCH_FILE=""
REVIEW_NOTES=""
TESTS_PERFORMED=""

usage() { grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --trigger-phase) TRIGGER_PHASE="$2"; shift 2 ;;
    --task-type) TASK_TYPE="$2"; shift 2 ;;
    --agent-behavior) AGENT_BEHAVIOR="$2"; shift 2 ;;
    --human-correction) HUMAN_CORRECTION="$2"; shift 2 ;;
    --rule) RULE="$2"; shift 2 ;;
    --applies-when) APPLIES_WHEN+=("$2"); shift 2 ;;
    --exceptions) EXCEPTIONS+=("$2"); shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --occurrence-count) OCCURRENCE_COUNT="$2"; shift 2 ;;
    --confidence) CONFIDENCE="$2"; shift 2 ;;
    --base-branch) BASE_BRANCH="$2"; shift 2 ;;
    --repo-dir) REPO_DIR="$2"; shift 2 ;;
    --target-file) TARGET_FILE_REL="$2"; shift 2 ;;
    --anchor) ANCHOR="$2"; shift 2 ;;
    --patch-file) PATCH_FILE="$2"; shift 2 ;;
    --review-notes) REVIEW_NOTES="$2"; shift 2 ;;
    --tests-performed) TESTS_PERFORMED="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

TARGET_FILE_REL="${TARGET_FILE_REL:-$DEFAULT_TARGET_FILE_REL}"
if [[ -n "$PATCH_FILE" && ! -f "$PATCH_FILE" ]]; then
  echo "--patch-file not found: $PATCH_FILE" >&2
  exit 1
fi

for req in ID TITLE RULE AGENT_BEHAVIOR HUMAN_CORRECTION; do
  if [[ -z "${!req:-}" ]]; then
    echo "Missing required --${req,,}" >&2
    exit 1
  fi
done
if [[ "$STATUS" != "candidate" && "$STATUS" != "promote" ]]; then
  echo "--status must be 'candidate' or 'promote'" >&2
  exit 1
fi
if [[ ! "$ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "--id must match ^[A-Za-z0-9._-]+\$ (got: $ID) — it becomes a git branch name and path segment" >&2
  exit 1
fi
if [[ ! "$OCCURRENCE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "--occurrence-count must be a non-negative integer (got: $OCCURRENCE_COUNT)" >&2
  exit 1
fi
if [[ ! "$CONFIDENCE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "--confidence must be a number (got: $CONFIDENCE)" >&2
  exit 1
fi

# Free-text fields become durable YAML (LEDGER.md) and, on --status promote,
# a binding Markdown rule fed back into future agent sessions via SKILL.md.
# Strip embedded newlines and escape double quotes so a value can never break
# out of its YAML scalar / Markdown bullet or corrupt a sibling field.
sanitize() { printf '%s' "$1" | tr '\n\r' '  ' | sed 's/"/\\"/g'; }
TITLE="$(sanitize "$TITLE")"
RULE="$(sanitize "$RULE")"
AGENT_BEHAVIOR="$(sanitize "$AGENT_BEHAVIOR")"
HUMAN_CORRECTION="$(sanitize "$HUMAN_CORRECTION")"
SESSION_ID="$(sanitize "${SESSION_ID:-}")"
TRIGGER_PHASE="$(sanitize "${TRIGGER_PHASE:-}")"
TASK_TYPE="$(sanitize "${TASK_TYPE:-}")"
REVIEW_NOTES="$(sanitize "${REVIEW_NOTES:-}")"
TESTS_PERFORMED="$(sanitize "${TESTS_PERFORMED:-}")"
for i in "${!APPLIES_WHEN[@]}"; do APPLIES_WHEN[$i]="$(sanitize "${APPLIES_WHEN[$i]}")"; done
for i in "${!EXCEPTIONS[@]}"; do EXCEPTIONS[$i]="$(sanitize "${EXCEPTIONS[$i]}")"; done

info()    { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }

cd "$REPO_DIR"
if [[ ! -d .git ]]; then
  echo "Not a git repo root: $REPO_DIR" >&2
  exit 1
fi

BRANCH="self-improve/${ID,,}"
# Use an in-repo scratch dir rather than system /tmp: some sandboxed agent
# environments restrict writes outside the repo/cwd tree, but always allow
# writes inside it. Kept out of git via .gitignore.
SCRATCH_ROOT="$REPO_DIR/.self-improve-tmp"
mkdir -p "$SCRATCH_ROOT"
WORKTREE_DIR="${SCRATCH_ROOT}/${ID,,}-$$"
cleanup() { git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true; rmdir "$SCRATCH_ROOT" 2>/dev/null || true; }
trap cleanup EXIT

info "Fetching origin/${BASE_BRANCH}..."
git fetch origin "$BASE_BRANCH" --quiet

info "Creating isolated worktree at $WORKTREE_DIR (branch: $BRANCH)"
# -B (not -b): re-running the same --id (the documented update/re-promote
# workflow) must reset a stale/leftover local branch rather than crash.
git worktree add -B "$BRANCH" "$WORKTREE_DIR" "origin/${BASE_BRANCH}" --quiet

LEDGER_FILE="$WORKTREE_DIR/corrections/LEDGER.md"
TARGET_FILE="$WORKTREE_DIR/$TARGET_FILE_REL"
if [[ "$STATUS" == "promote" && ! -f "$TARGET_FILE" ]]; then
  echo "--target-file not found in worktree: $TARGET_FILE_REL" >&2
  exit 1
fi

# ── Build the ledger entry ────────────────────────────────
{
  echo ""
  echo "### ${ID}"
  echo '```yaml'
  echo "id: ${ID}"
  echo "status: $([[ "$STATUS" == "promote" ]] && echo promoted || echo candidate)"
  echo "trigger:"
  echo "  phase: \"${TRIGGER_PHASE:-unspecified}\""
  echo "  task_type: \"${TASK_TYPE:-unspecified}\""
  echo "agent_behavior: \"${AGENT_BEHAVIOR}\""
  echo "human_correction: \"${HUMAN_CORRECTION}\""
  echo "durable_rule: \"${RULE}\""
  if [[ ${#APPLIES_WHEN[@]} -gt 0 ]]; then
    echo "applies_when:"
    for c in "${APPLIES_WHEN[@]}"; do echo "  - \"$c\""; done
  fi
  if [[ ${#EXCEPTIONS[@]} -gt 0 ]]; then
    echo "exceptions:"
    for c in "${EXCEPTIONS[@]}"; do echo "  - \"$c\""; done
  fi
  echo "evidence:"
  echo "  session_id: \"${SESSION_ID:-unknown}\""
  echo "  occurrence_count: ${OCCURRENCE_COUNT}"
  echo "confidence: ${CONFIDENCE}"
  echo '```'
} >> "$LEDGER_FILE"
success "Appended ${ID} to corrections/LEDGER.md"

# ── If promoting, apply a TARGETED patch (not a blind bottom-append) ─────
# Placement is the caller's job (see SELF_IMPROVEMENT.md § Placement duty):
# pass --anchor to insert right after an existing line (a checklist, a
# table, a section header) in --target-file, and --patch-file to supply
# the exact concise markdown to insert there (a table row, a tightened
# bullet, a small diagram) instead of an auto-generated paragraph. With
# neither, falls back to a single `- **[ID]** <rule>` bullet appended to
# --target-file (default LEARNED_CONSTRAINTS.md) — never SKILL.md's body.
if [[ "$STATUS" == "promote" ]]; then
  if [[ -n "$PATCH_FILE" ]]; then
    PATCH_CONTENT="$(cat "$PATCH_FILE")"
  else
    PATCH_CONTENT="- **[${ID}]** ${RULE}"
  fi

  # Idempotent: an existing block/bullet tagged with this ID is replaced,
  # not duplicated, on re-promotion (avoid mktemp: /tmp may not be
  # writable in sandboxed agent environments — use an in-repo scratch file).
  tmp="$SCRATCH_ROOT/patch-$$.tmp"
  if grep -qF "[${ID}]" "$TARGET_FILE"; then
    awk -v id="[${ID}]" -v content="$PATCH_CONTENT" '
      index($0, id) > 0 { print content; next } { print }
    ' "$TARGET_FILE" > "$tmp" && mv "$tmp" "$TARGET_FILE"
    info "Updated existing patch for ${ID} in ${TARGET_FILE_REL}"
  elif [[ -n "$ANCHOR" ]] && grep -qF "$ANCHOR" "$TARGET_FILE"; then
    awk -v anchor="$ANCHOR" -v content="$PATCH_CONTENT" '
      { print } index($0, anchor) > 0 { print content }
    ' "$TARGET_FILE" > "$tmp" && mv "$tmp" "$TARGET_FILE"
    info "Inserted targeted patch for ${ID} in ${TARGET_FILE_REL} after anchor"
  else
    if [[ -n "$ANCHOR" ]]; then
      warn "Anchor not found in ${TARGET_FILE_REL} — falling back to end-of-file append: $ANCHOR"
    fi
    { echo ""; echo "$PATCH_CONTENT"; } >> "$TARGET_FILE"
    info "Appended patch for ${ID} to end of ${TARGET_FILE_REL}"
  fi
fi

# ── Commit ─────────────────────────────────────────────────
cd "$WORKTREE_DIR"
git add corrections/LEDGER.md
[[ "$STATUS" == "promote" ]] && git add "$TARGET_FILE_REL"
git -c user.email="orchestrator@local" -c user.name="Manhattan Orchestrator" \
  commit --quiet -m "self-improve(${ID}): ${TITLE}" \
  -m "Status: ${STATUS}" \
  -m "Rule: ${RULE}"
success "Committed on branch $BRANCH"

if $DRY_RUN; then
  warn "Dry run — not pushing or opening a PR. Diff:"
  git show --stat HEAD
  exit 0
fi

REMOTE_URL="$(git -C "$REPO_DIR" remote get-url origin)"
SLUG="$(echo "$REMOTE_URL" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
COMPARE_URL="https://github.com/${SLUG}/compare/${BASE_BRANCH}...${BRANCH}?expand=1"

# ── Push + open PR ────────────────────────────────────────
# The branch ref itself lives in the shared .git dir, not the worktree, so
# it survives the cleanup trap's `worktree remove` regardless of what
# happens below — nothing here can lose the commit once it's made.
if git push --quiet -u origin "$BRANCH" 2>"$SCRATCH_ROOT/push-err.log"; then
  success "Pushed $BRANCH to origin"
else
  warn "Push failed (no git credentials in this environment?). The commit is safe"
  warn "on local branch '$BRANCH' in $REPO_DIR — push it yourself when you have"
  warn "credentials: git push -u origin $BRANCH"
  cat "$SCRATCH_ROOT/push-err.log" >&2 || true
  exit 1
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  PLACEMENT_DESC="${TARGET_FILE_REL}"
  [[ -n "$ANCHOR" ]] && PLACEMENT_DESC="${PLACEMENT_DESC} (after: \"${ANCHOR}\")"
  PR_BODY="$(cat <<PRBODY
## Reason for this change
${HUMAN_CORRECTION}

## What was done
- Agent behavior being corrected: ${AGENT_BEHAVIOR}
- Durable rule (status: ${STATUS}): ${RULE}
- Ledger entry: \`corrections/LEDGER.md\` § ${ID}
- Skill-file placement: ${PLACEMENT_DESC}

## How to review
1. Read the ledger entry (\`corrections/LEDGER.md\` § ${ID}) for full correction context (trigger phase: ${TRIGGER_PHASE:-unspecified}; task type: ${TASK_TYPE:-unspecified}).
2. Confirm the patch in ${TARGET_FILE_REL} reads as a targeted, concise addition in the surrounding section's existing tone — not a bottom-of-file paragraph.
3. Re-score against \`.github/CHANGE_RUBRIC.md\` independently before approving (per the double-blind rule — author's self-score is not sufficient).

## Tests performed
${TESTS_PERFORMED:-Self-scored against .github/CHANGE_RUBRIC.md before proposing (see ledger entry); this is a documentation/skill-instruction change with no executable test suite.}

Session: ${SESSION_ID:-unknown}
PRBODY
)"
  if PR_URL="$(gh pr create --base "$BASE_BRANCH" --head "$BRANCH" \
    --title "self-improve(${ID}): ${TITLE}" \
    --body "$PR_BODY" 2>"$SCRATCH_ROOT/gh-err.log")"; then
    success "Opened PR: $PR_URL"
  else
    warn "gh pr create failed — the branch was already pushed. Open the PR manually:"
    echo "$COMPARE_URL"
    cat "$SCRATCH_ROOT/gh-err.log" >&2 || true
  fi
else
  warn "gh CLI not available/authenticated — open the PR manually:"
  echo "$COMPARE_URL"
fi
