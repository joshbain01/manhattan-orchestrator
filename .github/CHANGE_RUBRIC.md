# Change Rubric: Does This PR Earn Its Place?

The orchestrator's value comes from being *used* — a fast, reliable, un-bloated playbook a
human can still read end-to-end. Every PR that touches `skills/manhattan-orchestrator/SKILL.md`
(and, by extension, any PR opened by the self-improvement loop — see
`scripts/propose-correction-pr.sh` and `corrections/README.md`) must be scored against this
rubric **before** it's considered eligible to merge, and again by the human reviewer.

This is a **hard gate for SKILL.md changes**: growth must be earned, not accumulated by default.

## The Rubric

Score each dimension 0–2. Record the scores in the PR description.

| # | Dimension | 0 | 1 | 2 |
|---|---|---|---|---|
| 1 | **Validated Value** | Speculative ("seems like good practice") | Plausible, reasoned from a specific observed gap | A specific, real failure this would have prevented — reproduced or cited (e.g. a session where the orchestrator did the wrong thing without this rule) |
| 2 | **Non-Duplication** | Restates/overlaps >50% of an existing rule without replacing it | Partial overlap, meaningfully narrows/sharpens existing guidance | Net-new concern; no existing rule covers it |
| 3 | **Proportionality** | Adds paragraphs/a new phase for a narrow, one-off situation | Size roughly matches how often this will matter | Minimal words for the value delivered (a single bullet, a tightened sentence) |
| 4 | **Interface Thinness** | Adds a new mandatory phase/template/flag every session must produce | Extends an existing phase's checklist | No growth to the mandatory surface — a clarification or a superseding edit |
| 5 | **Testability** | Purely aspirational prose with no way to check compliance | Checkable by a human reading the transcript | Checkable mechanically (a specific artifact, output, or behavior to grep for) |
| 6 | **Reversibility** | Buried inline, no way to identify/remove it later | Identifiable but not separately taggable | Tagged with a stable id (e.g. a `Learned Constraints` bullet keyed by correction id) so it can be pruned or superseded cleanly |

**Hard gate:** if **Validated Value = 0**, reject regardless of other scores — no
speculative rule gets added "just in case."

**Pass threshold:** total ≥ 8/12, **and** no individual dimension at 0 except where the
change is a pure *deletion/consolidation* (which trivially passes — shrinking the skill
never needs to justify itself the way growing it does).

## Consolidation duty (anti-bloat, not just anti-growth)

Bloat isn't only "too many new rules" — it's also *never pruning*. Any PR that promotes a
3rd+ rule under `## Learned Constraints` in a rolling 90-day window must also propose at
least one of: merging two overlapping rules, demoting a rule that hasn't mattered since it
was added, or restating multiple related bullets as one tighter rule. A PR that only adds
and never consolidates should be treated as a `Not-happy` signal at review time.

## Where this applies

- **Self-improvement loop:** before running `scripts/propose-correction-pr.sh --status
  promote`, self-score against this rubric and include the scores in the ledger's
  `human_correction`/`durable_rule` context (or the PR body). A `candidate` that can't
  clear the hard gate stays a `candidate` forever — it does not get "promoted by attrition."
- **Human-authored PRs to SKILL.md:** the author scores it; the reviewer (per
  `.github/CODEOWNERS`) re-scores independently before approving — score inflation by the
  author alone doesn't clear the gate (this mirrors the orchestrator's own "reviewer ≠
  author" double-blind rule).
- **Everything else** (new agent personas, docs, scripts): not gated by this rubric — it
  exists specifically to protect `SKILL.md` from unbounded growth, not to slow down
  ordinary additive contributions like a new specialist persona file.
