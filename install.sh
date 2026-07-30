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
# Everything OpenClaw-specific lives in this function (and the
# provision_openrouter_models helper it calls). It only ever talks to
# OpenClaw through its own `config set` / `config get` / `models ...` /
# `config validate` CLI — never by hand-editing ~/.openclaw/openclaw.json,
# and it never touches ~/.copilot/agents or ~/.agents/skills (those are
# already correctly wired by the install steps above; OpenClaw discovers
# both natively as-is).

# Sets a simple (non-shorthand-ambiguous) config path to a model value only
# if that path isn't already explicitly configured to something else — e.g.
# a Spark/vLLM model a user wired up per SPARK.md. Never clobbers an
# existing choice, including one this same script set on a prior run
# (indistinguishable from a user's own choice, and that's fine: idempotent
# means "reach the same end state", not "always refresh to the latest scan").
set_model_if_unset() {
  local path="$1" value="$2" label="$3"
  local current
  if current=$(openclaw config get "$path" 2>/dev/null); then
    if [ "$current" = "$value" ]; then
      success "$label already set to $value."
    else
      warn "$label is already set to '$current' — leaving it as-is (not overwriting with $value)."
    fi
    return 0
  fi
  if openclaw config set "$path" "$value" >/dev/null; then
    success "Set $label to $value"
    return 0
  fi
  warn "Failed to set $label."
  return 1
}

# Provisions OpenRouter as a cost-capped, dynamically-routed model source.
# Requires OPENROUTER_API_KEY in the environment — the raw key is never
# written to any file this script or the repo tracks; it is only ever piped
# on stdin into openclaw's own `models auth paste-api-key` CLI, which is
# what actually persists it (to the user's local auth store, outside the
# repo). No specific OpenRouter model ID is ever hardcoded here — the free
# model catalog changes over time, so candidates are discovered fresh on
# every run via `openclaw models scan`.
provision_openrouter_models() {
  if [ -z "${OPENROUTER_API_KEY:-}" ]; then
    warn "OPENROUTER_API_KEY not set, skipping OpenRouter model provisioning — see skills/manhattan-orchestrator/OPENCLAW.md"
    return 0
  fi

  info "Provisioning OpenRouter as a cost-capped, dynamically-routed model source…"

  # Register the key non-interactively. `paste-api-key` reads the key from
  # stdin (piped, no TTY needed) and writes it to the local auth-profiles
  # store under a dedicated `openrouter:manual` profile — it does not touch
  # or remove any other provider's auth profile, and rerunning it with the
  # same key is a no-op (same profile id, same value).
  if ! printf '%s' "$OPENROUTER_API_KEY" | openclaw models auth paste-api-key --provider openrouter >/dev/null; then
    warn "Failed to register OPENROUTER_API_KEY via 'openclaw models auth paste-api-key' — skipping OpenRouter model wiring."
    return 0
  fi
  success "OpenRouter auth profile registered (openrouter:manual)."

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found on PATH — cannot parse 'openclaw models scan' output, skipping free-model wiring."
    warn "The OpenRouter auth profile above is still registered; install jq and rerun 'bash install.sh --openclaw' to finish wiring."
    return 0
  fi

  # Discover current free, tool-capable OpenRouter models. --no-probe needs
  # no API key and does not make live inference calls; it just lists the
  # current free catalog from OpenRouter's model listing.
  local scan_json
  if ! scan_json=$(openclaw models scan --json --no-probe --yes --max-candidates 8 2>/dev/null); then
    warn "Failed to run 'openclaw models scan' — skipping free-model wiring (the auth profile above is still registered)."
    return 0
  fi

  local free_models
  if ! free_models=$(printf '%s' "$scan_json" | jq -r '[.[] | select(.supportsToolsMeta == true)][0:2][].modelRef'); then
    warn "Failed to parse 'openclaw models scan' output with jq — skipping free-model wiring (the auth profile above is still registered)."
    return 0
  fi
  if [ -z "$free_models" ]; then
    warn "No tool-capable free OpenRouter models found in scan results — skipping free-model wiring."
    return 0
  fi
  local model_1 model_2
  model_1=$(printf '%s\n' "$free_models" | sed -n '1p')
  model_2=$(printf '%s\n' "$free_models" | sed -n '2p')

  # `models fallbacks add` is OpenClaw's own scoped surface for this list —
  # it appends and de-dupes rather than replacing the array outright, so
  # any fallback entries a user already configured are preserved. Each call
  # is tracked independently, same reasoning as depth_set/children_set above:
  # a failure on one must not be reported as if nothing happened.
  local fallback_1_ok=true
  local fallback_2_ok=true
  if ! openclaw models fallbacks add "$model_1" >/dev/null; then
    fallback_1_ok=false
    warn "Failed to add fallback model $model_1."
  fi
  if [ -n "$model_2" ]; then
    if ! openclaw models fallbacks add "$model_2" >/dev/null; then
      fallback_2_ok=false
      warn "Failed to add fallback model $model_2."
    fi
  fi
  if $fallback_1_ok && { [ -z "$model_2" ] || $fallback_2_ok; }; then
    success "Added free OpenRouter fallback(s): $model_1${model_2:+, $model_2}"
  fi

  # Never clobber an existing utilityModel / subagents.model choice — e.g. a
  # Spark/vLLM model already wired up per SPARK.md's routing guidance
  # (agents.defaults.subagents.model is exactly what that doc tells readers
  # to set). Only wire the free model in if the path is currently unset.
  set_model_if_unset "agents.defaults.utilityModel" "$model_1" "agents.defaults.utilityModel" || true
  set_model_if_unset "agents.defaults.subagents.model" "$model_1" "agents.defaults.subagents.model" || true

  # Only point the primary model at OpenRouter's own dynamic per-prompt
  # router if nothing else is already explicitly configured there — never
  # clobber a deliberate existing primary-model choice.
  #
  # agents.defaults.model accepts EITHER a plain string (shorthand for
  # "primary") OR an object {primary, fallbacks} (per the config schema).
  # If a user already has the plain-string shorthand set, querying the
  # ".primary" sub-path returns "not found" even though a primary model
  # IS configured — naively treating that as "unset" and writing
  # agents.defaults.model.primary would silently convert their string into
  # an object and destroy their choice. So check the bare "agents.defaults.model"
  # value first and only ever treat it as unset if the whole key is absent.
  local current_model
  if current_model=$(openclaw config get agents.defaults.model 2>/dev/null); then
    case "$current_model" in
      "{"*)
        # Object shape — inspect .primary specifically.
        local current_primary
        current_primary=$(openclaw config get agents.defaults.model.primary 2>/dev/null || true)
        if [ -z "$current_primary" ]; then
          if openclaw config set agents.defaults.model.primary "openrouter/auto" >/dev/null; then
            success "Set agents.defaults.model.primary = openrouter/auto"
          else
            warn "Failed to set agents.defaults.model.primary."
          fi
        elif [ "$current_primary" = "openrouter/auto" ]; then
          success "agents.defaults.model.primary already set to openrouter/auto."
        else
          warn "agents.defaults.model.primary is already set to '$current_primary' — leaving it as-is (not overwriting with openrouter/auto)."
        fi
        ;;
      *)
        # Plain-string shorthand — a primary model is already explicitly
        # configured this way. Leave it alone entirely.
        warn "agents.defaults.model is already explicitly set to '$current_model' — leaving it as-is (not overwriting with openrouter/auto)."
        ;;
    esac
  else
    if openclaw config set agents.defaults.model.primary "openrouter/auto" >/dev/null; then
      success "Set agents.defaults.model.primary = openrouter/auto"
    else
      warn "Failed to set agents.defaults.model.primary."
    fi
  fi

  return 0
}

install_openclaw_integration() {
  info "Wiring up OpenClaw sub-agent orchestration…"

  if ! command -v openclaw >/dev/null 2>&1; then
    warn "OpenClaw not found on PATH, skipping OpenClaw config wiring."
    return 0
  fi

  # Enable main → orchestrator → worker nesting (default maxSpawnDepth is 1).
  # maxChildrenPerAgent is already 5 by default in OpenClaw — we still set it
  # explicitly so the value is visible in config rather than left implicit.
  # `config set` is idempotent, so rerunning this is always safe.
  #
  # The two `config set` calls are tracked independently rather than as a
  # single all-or-nothing unit: if one succeeds and the other fails, the
  # successful write is already durable in the user's real OpenClaw config,
  # so the messaging below must reflect that partial state instead of
  # implying nothing happened.
  local depth_set=true
  local children_set=true

  if ! openclaw config set agents.defaults.subagents.maxSpawnDepth 2; then
    depth_set=false
    warn "Failed to set agents.defaults.subagents.maxSpawnDepth."
  fi

  if ! openclaw config set agents.defaults.subagents.maxChildrenPerAgent 5; then
    children_set=false
    warn "Failed to set agents.defaults.subagents.maxChildrenPerAgent."
  fi

  if ! $depth_set && ! $children_set; then
    warn "Both OpenClaw subagent config writes failed — subagent-orchestration wiring did not apply."
  elif ! $depth_set || ! $children_set; then
    warn "OpenClaw subagent config was only partially applied (see warnings above)."
    warn "Some values were written to ~/.openclaw/openclaw.json, others were not — rerun 'bash install.sh --openclaw' to retry the missing one(s)."
  fi

  # OpenRouter model provisioning is independent of the subagent-depth
  # wiring above, so it still runs even if the subagent writes failed —
  # a broken subagent config shouldn't block model routing from being set up.
  provision_openrouter_models

  info "Validating OpenClaw config…"
  if openclaw config validate; then
    if $depth_set && $children_set; then
      success "OpenClaw subagent config wired: maxSpawnDepth=2, maxChildrenPerAgent=5"
    elif $depth_set || $children_set; then
      success "OpenClaw subagent config validated after a partial write (see warnings above)."
    fi
    warn "Restart the OpenClaw gateway for the new maxSpawnDepth to take effect."
    success "See skills/manhattan-orchestrator/OPENCLAW.md for the persona-injection pattern (sessions_spawn) and OpenRouter provisioning."
  else
    warn "OpenClaw config validation failed after setting subagent/model options."
    warn "Review the output above and check 'openclaw config get agents.defaults.subagents'."
    warn "Continuing install — this does not affect the skill/agents install above."
  fi

  # Always return success: OpenClaw wiring is never allowed to fail the
  # overall install, regardless of which branch above was taken.
  return 0
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
