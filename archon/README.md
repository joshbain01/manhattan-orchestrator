# Manhattan Orchestrator V2 for Archon

This directory packages the Manhattan Orchestrator V2 workflow for [Archon](https://archon.diy/). It is independent of the repository's existing VS Code Copilot skill installer and does not alter `install.sh`, `skills/`, or `agents/`.

## Contents

```text
archon/
├── install.sh                         # Non-destructive project installer
├── workflows/
│   └── manhattan-orchestrator-v2.yaml # Jira-first implementation and QA DAG
├── commands/
│   └── archon-ralph-generate.md       # Fallback idea/PRD decomposition command
└── docs/
    ├── ARCHON_SETUP.md                # Install and configure the Archon runtime
   └── manhattan-orchestrator-v2-onboarding.html
                              # Visual, print-friendly workflow guide
```

## Quick Start

1. Follow [docs/ARCHON_SETUP.md](docs/ARCHON_SETUP.md) to install Archon, connect Anthropic, authenticate GitHub, and configure Jira.
2. Install the workflow into a product repository:

   ```bash
   bash archon/install.sh /absolute/path/to/product-repository
   ```

3. Validate from the product repository:

   ```bash
   cd /absolute/path/to/product-repository
   archon validate workflows manhattan-orchestrator-v2 --json
   ```

4. Run with a Jira parent ticket:

   ```bash
   archon workflow run manhattan-orchestrator-v2 \
     --branch feat/SAP-3560-voice-health \
     "SAP-3560"
   ```

## Safety Properties

- Jira is the authoritative specification for Jira-backed runs.
- Work begins in an isolated worktree after synchronizing with the latest base branch.
- An independent Explorer catalogs component interfaces before implementation.
- Broad staging, workflow-state files, obvious secrets, and out-of-scope files are blocked.
- Tests and browser checks run before independent domain review.
- Frontend, code, and architecture reviewers are separate from the implementer.
- `push-and-pr` is the only workflow node authorized to publish remotely.
- Review findings are persisted as lessons for later runs.

## Updating the Package

Update `workflows/manhattan-orchestrator-v2.yaml` and `commands/archon-ralph-generate.md` from a validated Archon source checkout. Before committing:

```bash
archon validate workflows manhattan-orchestrator-v2 --json
bash -n archon/install.sh
```

Never copy Archon's generated bundle, runtime database, `.env`, `.archon/ralph/` state, screenshots, or product-specific files into this repository.
