#!/usr/bin/env bash
# ============================================================
#  Manhattan Orchestrator — Install Script
#  https://github.com/jbain/manhattan-orchestrator
#
#  Usage:
#    bash install.sh                      # install everything
#    bash install.sh --skill-only         # install skill only (skip agent personas)
#    bash install.sh --agents-only        # install agent personas only (skip skill)
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DEST="$HOME/.agents/skills/manhattan-orchestrator"
AGENTS_DEST="$HOME/.copilot/agents"
INSTALL_SKILL=true
INSTALL_AGENTS=true

# ── Argument parsing ──────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --skill-only)  INSTALL_AGENTS=false ;;
    --agents-only) INSTALL_SKILL=false ;;
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
