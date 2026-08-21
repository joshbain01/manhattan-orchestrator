#!/usr/bin/env bash
# Install the Manhattan Ralph workflow into an Archon project without overwriting files.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$PWD}"
FORCE="${ARCHON_INSTALL_FORCE:-false}"

if [[ "${2:-}" == "--force" ]] || [[ "${1:-}" == "--force" ]]; then
  FORCE=true
  if [[ "${1:-}" == "--force" ]]; then
    TARGET_DIR="$PWD"
  fi
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
WORKFLOW_DEST="$TARGET_DIR/.archon/workflows/archon-ralph-dag.yaml"
COMMAND_DEST="$TARGET_DIR/.archon/commands/archon-ralph-generate.md"

if ! git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR: target is not a Git repository: %s\n' "$TARGET_DIR" >&2
  printf 'Initialize or clone the product repository before installing this workflow.\n' >&2
  exit 1
fi

preflight_file() {
  local source="$1"
  local destination="$2"
  local parent

  for parent in "$TARGET_DIR/.archon" "$(dirname "$destination")" "$destination" "$destination.bak"; do
    if [[ -L "$parent" ]]; then
      printf 'ERROR: refusing symlinked install path: %s\n' "$parent" >&2
      return 1
    fi
  done

  if [[ -e "$destination" ]] && ! cmp -s "$source" "$destination" && [[ "$FORCE" != "true" ]]; then
    printf 'ERROR: refusing to overwrite existing file: %s\n' "$destination" >&2
    printf 'Review the diff, then rerun with --force only if replacement is intentional.\n' >&2
    return 1
  fi
}

validate_install_paths() {
  local target_real
  local destination
  local parent
  local parent_real

  target_real=$(realpath "$TARGET_DIR")
  for destination in "$WORKFLOW_DEST" "$COMMAND_DEST"; do
    parent=$(dirname "$destination")
    if [[ -L "$TARGET_DIR/.archon" || -L "$parent" || -L "$destination" || -L "$destination.bak" ]]; then
      printf 'ERROR: refusing symlinked install path: %s\n' "$destination" >&2
      return 1
    fi

    parent_real=$(realpath "$parent")
    case "$parent_real/" in
      "$target_real/"*) ;;
      *)
        printf 'ERROR: install destination escapes target repository: %s\n' "$destination" >&2
        return 1
        ;;
    esac
  done
}

# Check every destination before writing either file, so a conflict cannot leave
# a mixed workflow/command version behind.
preflight_file "$REPO_DIR/workflows/archon-ralph-dag.yaml" "$WORKFLOW_DEST"
preflight_file "$REPO_DIR/commands/archon-ralph-generate.md" "$COMMAND_DEST"

STAGE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/manhattan-archon-install-XXXXXX")
ROLLBACK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/manhattan-archon-rollback-XXXXXX")
cleanup() { rm -rf "$STAGE_DIR" "$ROLLBACK_DIR"; }
trap cleanup EXIT

cp "$REPO_DIR/workflows/archon-ralph-dag.yaml" "$STAGE_DIR/workflow.yaml"
cp "$REPO_DIR/commands/archon-ralph-generate.md" "$STAGE_DIR/command.md"
cmp -s "$REPO_DIR/workflows/archon-ralph-dag.yaml" "$STAGE_DIR/workflow.yaml"
cmp -s "$REPO_DIR/commands/archon-ralph-generate.md" "$STAGE_DIR/command.md"

workflow_existed=false
command_existed=false
[[ -e "$WORKFLOW_DEST" ]] && { cp -p "$WORKFLOW_DEST" "$ROLLBACK_DIR/workflow.yaml"; workflow_existed=true; }
[[ -e "$COMMAND_DEST" ]] && { cp -p "$COMMAND_DEST" "$ROLLBACK_DIR/command.md"; command_existed=true; }

rollback() {
  if $workflow_existed; then cp -p "$ROLLBACK_DIR/workflow.yaml" "$WORKFLOW_DEST"; else rm -f "$WORKFLOW_DEST"; fi
  if $command_existed; then cp -p "$ROLLBACK_DIR/command.md" "$COMMAND_DEST"; else rm -f "$COMMAND_DEST"; fi
}

mkdir -p "$(dirname "$WORKFLOW_DEST")" "$(dirname "$COMMAND_DEST")"
validate_install_paths

if [[ "$FORCE" == "true" ]]; then
  $workflow_existed && { cp -p "$ROLLBACK_DIR/workflow.yaml" "$WORKFLOW_DEST.bak"; printf '[backup]    %s\n' "$WORKFLOW_DEST.bak"; }
  $command_existed && { cp -p "$ROLLBACK_DIR/command.md" "$COMMAND_DEST.bak"; printf '[backup]    %s\n' "$COMMAND_DEST.bak"; }
fi

# Recheck immediately before the live writes so a path swap after preflight
# cannot redirect installation outside the requested repository.
validate_install_paths
if ! cp "$STAGE_DIR/workflow.yaml" "$WORKFLOW_DEST" || ! cp "$STAGE_DIR/command.md" "$COMMAND_DEST"; then
  rollback
  printf 'ERROR: installation failed; destination files were rolled back.\n' >&2
  exit 1
fi

printf '[installed] %s\n' "$WORKFLOW_DEST"
printf '[installed] %s\n' "$COMMAND_DEST"

printf '\nArchon Ralph resources installed into %s\n' "$TARGET_DIR"
printf 'Next: cd %q && archon validate workflows archon-ralph-dag --json\n' "$TARGET_DIR"
