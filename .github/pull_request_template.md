<!--
This repo requires human review before merge (see .github/CODEOWNERS).
Any automation that opens PRs (e.g. a self-improvement/agentic loop) must NOT
approve or merge its own PRs — only @joshbain01 after review.
-->

## What changed

## Why

## Change Rubric (required if this touches skills/manhattan-orchestrator/SKILL.md)
See `.github/CHANGE_RUBRIC.md`. Score each 0–2:
- [ ] Validated Value: __ /2 (if 0, this PR should not be merged — reject and explain why here instead)
- [ ] Non-Duplication: __ /2
- [ ] Proportionality: __ /2
- [ ] Interface Thinness: __ /2
- [ ] Testability: __ /2
- [ ] Reversibility: __ /2
- **Total: __ /12** (pass threshold ≥ 8, and Validated Value must not be 0)
- [ ] If this is the 3rd+ new `Learned Constraints` rule in the last 90 days, this PR also
      consolidates/prunes at least one existing rule (see "Consolidation duty").

## Verification
- [ ] I (a human) reviewed this before merging.
- [ ] If this touches `skills/manhattan-orchestrator/SKILL.md`, I confirmed the change doesn't
      widen the orchestrator's public interface or weaken a seam without a stated reason.
- [ ] I independently re-scored the Change Rubric above rather than trusting the author's
      self-score (reviewer ≠ author, same as the orchestrator's own double-blind rule).
