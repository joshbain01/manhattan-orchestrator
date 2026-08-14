# Self-Improvement Loop: Correction Ledger

This directory is the durable, git-controlled memory for the Manhattan Orchestrator's
self-improvement loop (see `skills/manhattan-orchestrator/SKILL.md`, "Self-Improvement Loop").

It exists to close one loop: **a human corrects the orchestrator → the correction is
distilled into a rule → the rule is either logged or, once it matters, proposed as a
change to the orchestrator's own skill file via a PR** — so the same course-correction
doesn't have to be repeated every session.

## Files

- `LEDGER.md` — append-only, human-readable log of every distilled correction (candidate
  and promoted). This is the seam: sessions only ever *append* here; nothing else reads
  or writes it except `scripts/propose-correction-pr.sh`.

## Correction schema

Each ledger entry is a small YAML block:

```yaml
id: CORR-YYYY-MM-DD-NNN
status: candidate | promoted
trigger:
  phase: <playbook phase where the correction happened>
  task_type: <short description of the task>
agent_behavior: <what the orchestrator did>
human_correction: <what the human corrected>
durable_rule: <the rule statement to apply going forward>
applies_when:
  - <condition>
exceptions:
  - <condition that overrides the rule>
evidence:
  session_id: <session identifier, if available>
  occurrence_count: <N>
confidence: <0.0-1.0>
```

## Promotion policy

- **First occurrence** of a correction → logged as `candidate` in `LEDGER.md` only. No PR.
  Low friction, doesn't bloat the skill file for a one-off.
- **Explicit durable-rule language** from the human ("from now on", "always", "never",
  "in general", a generalizing correction) → promote immediately: open a PR that appends
  the rule to SKILL.md's "Learned Constraints" section.
- **Recurrence** — the same or a materially similar `candidate` correction appears a second
  time (same `task_type`/`trigger.phase` and a similar `agent_behavior`) → auto-promote on
  the second occurrence.
- **Superseding** — if a new rule contradicts an existing promoted rule, the new PR must
  mark the old rule superseded (strike it, don't silently leave both), citing the old `id`.

## How a correction becomes a PR

Run `scripts/propose-correction-pr.sh` (see its `--help`). It:
1. Creates an isolated git worktree off `origin/main` (never disturbs your current checkout).
2. Appends the entry to `corrections/LEDGER.md`.
3. If `--status promote`, also inserts/updates the rule under SKILL.md's
   "Learned Constraints (self-improvement loop)" section.
4. Commits, pushes the branch, and opens a PR via `gh` if it's installed and authenticated —
   otherwise prints a ready-to-click GitHub compare URL so you can open the PR by hand.
5. Removes the temporary worktree.

This keeps the mechanism dependency-free: it degrades gracefully with no `gh` CLI and no
GitHub token in the environment, which is the common case in a sandboxed agent session.

## Operational caveat: merging concurrent self-improvement PRs

Because `LEDGER.md` is append-only, two self-improvement PRs opened from the same base
`main` (e.g. two sessions running back-to-back before either PR is merged) **will conflict
on merge** if merged sequentially without updating branches first — this is standard git
behavior for concurrent tail-appends to the same file, not a script bug. Verified via a
full e2e run (two isolated clones, two PR branches off the same base, sequential merge).

Mitigation: merge/rebase one self-improvement PR at a time, using GitHub's "Update branch"
(or `git rebase origin/main`) on the second PR before merging it — the conflict, when it
occurs, is trivial (keep both appended entries).

