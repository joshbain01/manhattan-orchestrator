# Correction Ledger

Append-only. See `README.md` in this directory for the schema and promotion policy.
Entries are appended by `scripts/propose-correction-pr.sh` — do not hand-edit except to
fix a typo in an existing entry.

<!-- ENTRIES BELOW THIS LINE -->

### CORR-2026-08-14-001
```yaml
id: CORR-2026-08-14-001
status: promoted
trigger:
  phase: "Phase 5: Delivery"
  task_type: "opportunistic UX/visual change discovered during ticket implementation"
agent_behavior: "While implementing SAP-3564, discovered and unilaterally applied two UX-affecting changes (moved the Ask Sapphire button position in BlufPanel; redesigned the BLUF loading/timeout messaging) without first presenting them to the human as discrete, approvable decisions."
human_correction: "I would like to have had the agent flag these to me to see if they should be made, so I can easily approve, disapprove, or provide guidance -- this is part of the mantra that the orchestrator should enable me to have as much free time as possible by finding visual bugs for me to evaluate quickly. In the future, the orchestrator will write comments in Jira tickets with these observations and request guidance, and be prepared to generate marked-up screenshots to attach so I can decide quickly."
durable_rule: "When the orchestrator discovers a visual/UX-affecting issue or improvement opportunity during implementation that goes beyond the literal, explicit ask, it must not silently fold the change into the delivered diff. It must surface the finding as a discrete, approvable decision -- describe the issue/options, attach a marked-up/annotated screenshot when the finding is visual, and request guidance (preferably as a comment on the originating Jira ticket when the work is ticket-driven) -- before implementing. Exception: a change required for the literal ask to function (a blocking bug in the requested feature itself) may still be fixed directly, but must be called out in delivery as an in-scope necessary fix, distinguished from an opportunistic improvement."
applies_when:
  - "The orchestrator finds a UX/visual inconsistency, redesign opportunity, or behavioral change adjacent to but not required by the literal task"
  - "The change affects what a user sees/experiences (layout, positioning, messaging/timing UX) rather than being strictly necessary for the literal ask to function"
  - "The task originated from a Jira ticket or other tracked work item"
exceptions:
  - "The change is required for the literal ask to function correctly (a blocking bug in the requested feature itself)"
  - "The human has already granted blanket approval for this class of change earlier in the session"
evidence:
  session_id: "4b1b16ec-f9fd-4e99-8de7-672afca9f3dc"
  occurrence_count: 1
confidence: 0.9
```

### CORR-2026-08-14-003
```yaml
id: CORR-2026-08-14-003
status: promoted
trigger:
  phase: "Phase 5.4: Ticket-Driven Git Workflow"
  task_type: "git history-rewriting action performed without confirmation"
agent_behavior: "Ran 'git reset --hard' on a branch to reconcile it with an upstream change, then 'git push --force-with-lease' to update the remote branch, without asking the human first -- despite this being explicitly listed as an action requiring confirmation."
human_correction: "dont force push!"
durable_rule: "Never run 'git push --force'/--force-with-lease or 'git reset --hard' without first asking the human and getting an explicit go-ahead -- regardless of whether the branch appears to be solely the orchestrator's own work-in-progress. If reconciling a branch with an upstream change requires a force-push or hard reset, stop and ask; propose a non-destructive alternative (e.g. a merge commit, or a fresh branch) when one exists."
applies_when:
  - "A branch needs to be reset or force-pushed to reconcile with new upstream commits"
  - "The orchestrator created the branch itself earlier in the same session"
exceptions:
  - "The human has explicitly pre-authorized force-push/reset for this specific branch in this session"
evidence:
  session_id: "4b1b16ec-f9fd-4e99-8de7-672afca9f3dc"
  occurrence_count: 1
confidence: 1.0
```
