# OpenClaw Adapter Notes

This is reference material, not a skill of its own. It exists to translate the
patterns in [`SKILL.md`](./SKILL.md) — written against Claude Code's `Task`
tool — into [OpenClaw](https://docs.openclaw.ai)'s native sub-agent primitive,
`sessions_spawn`. Read `SKILL.md` first; this file only covers what's
different when the orchestrator is running under OpenClaw.

---

## 1. Skill discovery already works — no action needed

OpenClaw auto-discovers skills from `~/.agents/skills/*/SKILL.md`. That's the
same shared, cross-tool convention `install.sh` already installs into, so
`skills/manhattan-orchestrator/SKILL.md` is picked up by OpenClaw as-is.
Nothing in this repo's skill-install step (`install.sh`, no flags, or
`--skill-only`) needs to change for OpenClaw.

Verify with:

```bash
$ openclaw skills info manhattan-orchestrator
manhattan-orchestrator ✓ Ready

Expert Orchestrator for solving ambiguous, complex problems...

Details:
  Source: agents-skills-personal
  Path: ~/.agents/skills/manhattan-orchestrator/SKILL.md
  Visible to model: yes
  Available as command: yes
```

Likewise, the engineering persona files installed to `~/.copilot/agents/` by
the agents-install step are plain Markdown files. Any OpenClaw agent can
`Read` them directly at that path — there is no OpenClaw-specific copy or
duplication step. The only genuine gap is described below: OpenClaw's
sub-agent tool has a different call contract than Claude Code's `Task`/`Agent`
tool, so the *spawn call itself* needs an adapter.

---

## 2. Persona Injection Pattern → `sessions_spawn`

SKILL.md §6.2 describes spawning an Engineering Sub-Agent by reading its
persona file and prepending it to a `Task`-tool prompt, using
`agent_type: "general-purpose"`. OpenClaw has no `Task`/`Agent` tool; its
equivalent primitive is the `sessions_spawn` tool, with this contract:

| Param | Required | Notes |
| :--- | :--- | :--- |
| `task` | yes | The full prompt string for the sub-agent |
| `taskName` | no | Stable handle (`[a-z][a-z0-9_-]{0,63}`) for referencing this specific child later in status output — not a session key, just a model-facing alias |
| `label` | no | Short human-readable label for the spawned session |
| `agentId` | no | Spawn under another configured agent id (subject to `subagents.allowAgents`) |
| `model` | no | Override model for this sub-agent run |
| `thinking` | no | Thinking-effort override for this sub-agent run |
| `mode` | no | `run` (default) or `session` — `session` requires `thread: true` |

`sessions_spawn` also accepts `cwd`, `runtime`, `thread`, `cleanup`, `sandbox`,
and `context` (plus ACP-only params). Those aren't needed for the persona
injection pattern here — see [OpenClaw's sub-agent docs](https://docs.openclaw.ai/tools/subagents)
for the full list.

**Important:** there is no per-call timeout parameter. `runTimeoutSeconds` is
a **config-level** default only (`agents.defaults.subagents.runTimeoutSeconds`,
default `0` = no timeout) — `sessions_spawn` itself does not accept a
per-call timeout override.

There is no `agent_type` concept — OpenClaw doesn't distinguish a
"general-purpose" agent type at the spawn boundary. All persona, mission, and
constraints must be folded into the single `task` string, exactly the same
way SKILL.md §6.2 already builds its `prompt` variable. The translation is
mechanical:

```
Claude Code Task tool          →   OpenClaw sessions_spawn
────────────────────────────────────────────────────────────
agent_type: "general-purpose"  →   (omit — no equivalent; the persona
                                     text in `task` fully determines behavior)
name: "software-architect"     →   label: "software-architect"
prompt: f"""{persona}...."""   →   task: f"""{persona}...."""
```

### Adapter recipe

1. Read the persona file: `~/.copilot/agents/engineering-{name}.md`
2. Concatenate persona + mission + output contract into one string, same
   shape as SKILL.md §6.2's `prompt` variable:

   ```python
   import os

   # {name} below is a placeholder — substitute the actual persona short
   # name, e.g. "software-architect" (see the worked example below).
   persona_path = os.path.expanduser("~/.copilot/agents/engineering-{name}.md")
   persona = open(persona_path).read()

   task = f"""
   {persona}

   ---

   ## Your Mission

   {specific_task_description}

   ## Output Contract

   {exactly_what_to_return}

   ## Constraints

   - Work autonomously. Use sessions_spawn for research, implementation, and
     verification sub-tasks as needed (see §3 below for depth limits).
   - Follow the workflow and deliverable standards defined in your persona above.
   - Report back only the output contract items. Do not narrate your process.
   """
   ```

3. Call `sessions_spawn` with that `task` string and a sensible `label`
   (e.g. the persona short name).

### Worked example — spawning the Software Architect persona

```python
import os

persona_path = os.path.expanduser("~/.copilot/agents/engineering-software-architect.md")
persona = open(persona_path).read()

sapphire_path = os.path.expanduser("~/apps/sapphire/sapphire-pipeline/")

task = f"""
{persona}

---

## Your Mission

Design the data access layer for the Sapphire pipeline module.
Produce: (1) a module boundary diagram, (2) the public interface contract
(max 5 methods), (3) an ADR template.

## Output Contract

Return a structured Markdown document with the three deliverables above.

## Constraints

- Use sessions_spawn to spawn a Researcher sub-agent to explore
  {sapphire_path} first.
- Use sessions_spawn to spawn an Architecture Auditor sub-agent to validate
  your interface for width before returning.
"""

sessions_spawn(
    task=task,
    label="software-architect",
)
```

The Researcher and Architecture Auditor calls inside that sub-agent's own
constraints are themselves `sessions_spawn` calls made *by* the spawned
Software Architect session — see §3 for why that requires raising
`maxSpawnDepth`.

---

## 3. Three-tier depth mapping

SKILL.md §6.1 defines three tiers (Orchestrator → Specialist → Worker).
OpenClaw expresses nesting depth through session IDs, not an explicit "tier"
field:

| SKILL.md tier | OpenClaw session ID shape | Role |
| :--- | :--- | :--- |
| Tier 1 — Manhattan Orchestrator | `agent:<id>:main` | Coordinates, audits, verifies. Selects the specialist and defines the output contract. |
| Tier 2 — Engineering Specialist | `agent:<id>:subagent:<uuid>` | Domain expert spawned by Tier 1 via `sessions_spawn`. Owns execution of its slice, has the full persona injected into `task`. |
| Tier 3 — Worker Sub-Agent | `agent:<id>:subagent:<uuid>:subagent:<uuid>` | Narrow-scope executor (Researcher / Implementer / Verifier) spawned by the Tier 2 specialist via its own `sessions_spawn` call. |

This nesting — a sub-agent spawning its own sub-agent — is exactly OpenClaw's
documented "orchestrator pattern," and it is **only reachable** if
`agents.defaults.subagents.maxSpawnDepth` is raised from its default of `1` to
`2`. At the default depth of `1`, a Tier 2 specialist's attempt to spawn a
Tier 3 worker is rejected. `install.sh --openclaw` sets this automatically
(see the repo README's OpenClaw section for how to run it); it also sets
`maxChildrenPerAgent` to `5`, which is already OpenClaw's own default — this
just pins it explicitly rather than changing behavior.

**Gateway restart required:** `openclaw config set` writes the new
`maxSpawnDepth` to `~/.openclaw/openclaw.json` immediately, but the running
gateway process does not pick it up until it's restarted. The three-tier
nesting above will not actually work until you restart the OpenClaw gateway
after running `install.sh --openclaw`.
