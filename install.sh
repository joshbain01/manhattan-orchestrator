#!/usr/bin/env bash
# ============================================================
#  Manhattan Orchestrator — Install Script
#  https://github.com/jbain/manhattan-orchestrator
#
#  Usage:
#    bash install.sh                      # install everything
#    bash install.sh --skill-only         # install skill only (skip agent personas)
#    bash install.sh --agents-only        # install agent personas only (skip skill)
#    bash install.sh --openclaw           # also wire up OpenClaw sub-agent config
#                                          # (combinable with the flags above;
#                                          #  opt-in only — omitting it changes
#                                          #  nothing about the default install)
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DEST="$HOME/.agents/skills/manhattan-orchestrator"
AGENTS_DEST="$HOME/.copilot/agents"
INSTALL_SKILL=true
INSTALL_AGENTS=true
INSTALL_OPENCLAW=false

# ── Argument parsing ──────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --skill-only)  INSTALL_AGENTS=false ;;
    --agents-only) INSTALL_SKILL=false ;;
    --openclaw)    INSTALL_OPENCLAW=true ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────
info()    { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }

# ── Install skill ─────────────────────────────────────────
if $INSTALL_SKILL; then
  info "Installing skill → $SKILLS_DEST"
  mkdir -p "$SKILLS_DEST"
  sed "s|/home/jbain/|$HOME/|g" \
    "$REPO_DIR/skills/manhattan-orchestrator/SKILL.md" \
    > "$SKILLS_DEST/SKILL.md"
  success "Skill installed: $SKILLS_DEST/SKILL.md"
fi

# ── Install agent personas ─────────────────────────────────
if $INSTALL_AGENTS; then
  info "Installing 58 engineering agent personas → $AGENTS_DEST"
  mkdir -p "$AGENTS_DEST"
  cp "$REPO_DIR/agents/"*.md "$AGENTS_DEST/"
  AGENT_COUNT=$(ls "$AGENTS_DEST"/engineering-*.md 2>/dev/null | wc -l)
  success "$AGENT_COUNT agent persona files installed: $AGENTS_DEST"
fi

# ── OpenClaw wiring ────────────────────────────────────────
# Everything OpenClaw-specific lives in this one function. It only ever
# talks to OpenClaw through its own `config set` / `config validate` CLI —
# never by hand-editing ~/.openclaw/openclaw.json, and it never touches
# ~/.copilot/agents or ~/.agents/skills (those are already correctly wired
# by the install steps above; OpenClaw discovers both natively as-is).
install_openclaw_integration() {
  info "Wiring up OpenClaw sub-agent orchestration…"

  if ! command -v openclaw >/dev/null 2>&1; then
    warn "OpenClaw not found on PATH, skipping OpenClaw config wiring."
    return 0
  fi

  # Enable main → orchestrator → worker nesting (default maxSpawnDepth is 1).
  # `config set` is idempotent, so rerunning this is always safe.
  if ! openclaw config set agents.defaults.subagents.maxSpawnDepth 2 \
    || ! openclaw config set agents.defaults.subagents.maxChildrenPerAgent 5; then
    warn "Failed to set OpenClaw subagent options — skipping OpenClaw wiring."
    warn "Continuing install; skill/agents install above is unaffected."
    return 0
  fi

  info "Validating OpenClaw config…"
  if openclaw config validate; then
    success "OpenClaw config wired: maxSpawnDepth=2, maxChildrenPerAgent=5"
    success "See skills/manhattan-orchestrator/OPENCLAW.md for the persona-injection pattern (sessions_spawn)."
  else
    warn "OpenClaw config validation failed after setting subagent options."
    warn "Review the output above and check 'openclaw config get agents.defaults.subagents'."
    warn "Continuing install — this does not affect the skill/agents install above."
  fi
}

if $INSTALL_OPENCLAW; then
  install_openclaw_integration
fi

# ── VS Code settings reminder ─────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────"
echo "  NEXT STEP: Configure VS Code to discover the skill"
echo "────────────────────────────────────────────────────────"
echo ""
echo '  Open VS Code settings (Ctrl+,) → "Open Settings JSON"'
echo '  and add (or merge) this entry:'
echo ""
echo '  "github.copilot.chat.promptFilesLocations": ['
echo '    "~/.agents/skills"'
echo '  ]'
echo ""
echo "  Then reload VS Code and type /manhattan-orchestrator"
echo "  in Copilot Chat to confirm the skill is active."
echo ""
success "Done!"
