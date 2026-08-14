# Self-Improvement Loop — Mechanics (reference — loaded on demand from SKILL.md § 7)

Full policy for turning a detected correction (SKILL.md § 7, trigger check) into a
durable, git-controlled rule. Read this file only once § 7's trigger check fires.

**Thin interface:** one script, `scripts/propose-correction-pr.sh`, in the
manhattan-orchestrator repo. **Deep module:** all git worktree/branch/commit/push/PR
plumbing lives inside it. **Seam:** `corrections/LEDGER.md` is the append-only handoff
between "a session learned something" and "the skill file changed."

## Distillation Schema
Convert the correction into this structure (persisted verbatim in the ledger — see
`corrections/README.md` for the full schema and rationale):

```yaml
id: CORR-YYYY-MM-DD-NNN
trigger: { phase: <playbook phase>, task_type: <short description> }
agent_behavior: <what you did>
human_correction: <what the human corrected>
durable_rule: <the rule, stated so it can be mechanically checked next time>
applies_when: [<condition>, ...]
exceptions: [<condition that overrides the rule>, ...]
evidence: { session_id: <id>, occurrence_count: <N> }
confidence: <0.0-1.0>
```

## Promotion Policy (candidate vs. promote)
| Situation | Action |
|---|---|
| First occurrence, no generalizing language | `--status candidate` — logged to `corrections/LEDGER.md` only, no PR |
| Explicit generalizing language ("always", "never", "from now on") | Promote immediately, regardless of occurrence count |
| Recurrence of a similar `candidate` (same `trigger.phase` + similar `agent_behavior`) | Auto-promote on the 2nd occurrence |
| Contradicts a previously promoted rule | New rule must explicitly supersede it (cite the old `id`) — never silently coexist |

**Anti-bloat gate (mandatory, no exceptions):** before `--status promote`, self-score the
rule against `.github/CHANGE_RUBRIC.md`. `Validated Value = 0` → stays `candidate` forever,
no exceptions. Include the rubric scores in the PR body.

**Consolidation duty:** every promotion must check whether an existing rule in
`LEARNED_CONSTRAINTS.md` can be merged, tightened, or demoted — not just gated at the 3rd+
rule. Growth without an accompanying pruning check is a `Not-happy` signal at review time.

**Placement duty (not a bottom-of-file append):** a promoted rule must be placed as a
**targeted, concise patch** into the most relevant existing section/table/checklist it
naturally belongs to (prefer a tightened bullet, a new table row, or a short diagram over
a new paragraph). Only fall back to a new `LEARNED_CONSTRAINTS.md` bullet when no existing
section fits. Match the surrounding tone/format — do not introduce a new format per rule.

## Invocation
```
scripts/propose-correction-pr.sh \
  --id CORR-2026-08-14-001 --status promote|candidate \
  --title "<short summary>" --trigger-phase "<phase>" --task-type "<type>" \
  --agent-behavior "<...>" --human-correction "<...>" --rule "<...>" \
  --applies-when "<condition>" [--applies-when "<condition>" ...] \
  --exceptions "<condition>" --session-id "<id>" \
  [--target-file "<relative path, default: skills/manhattan-orchestrator/LEARNED_CONSTRAINTS.md>"] \
  [--anchor "<exact existing line to insert after — enables targeted placement>"] \
  [--patch-file "<path to hand-authored concise markdown block — table row, tightened bullet, small diagram>"] \
  [--dry-run]
```
It creates an isolated git worktree off `origin/<base-branch>` (never touches your current
checkout), appends the ledger entry, patches the target file if promoting (at `--anchor` if
given, else at that file's own designated insertion point), commits, pushes, and opens a PR
via `gh` if available — otherwise prints a ready-to-click GitHub compare URL. Degrades
gracefully with no `gh` CLI / no GitHub token — never fails silently.

**Authoring the patch is the orchestrator's job, not the script's.** Before invoking with
`--status promote`, decide the correct home for the rule yourself (an existing checklist,
table, or `LEARNED_CONSTRAINTS.md` as last resort) and write it in the surrounding
document's tone — the script only handles the git/PR mechanics reliably.

## Isolation Rule
The script runs as a narrow, single-purpose worker (Tier 3) — invoke it directly; do not
wrap it in a general-purpose sub-agent. It has no need-to-know beyond the distilled
correction fields passed on its command line.
