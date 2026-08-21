# Set Up Archon for Manhattan Orchestrator V2

This guide installs and configures the **Archon runtime**. It is intentionally separate from the repository's existing Manhattan Orchestrator installation instructions.

## What You Need

- macOS, Linux, or Windows through WSL2
- Git and a Git repository for the product you want Archon to modify
- GitHub CLI (`gh`) authenticated for the product repository
- An Anthropic API key or subscription credential
- Jira Cloud credentials with permission to read the parent ticket, create subtasks, transition issues, and add comments

## 1. Install Archon

Choose one supported installation path.

### Quick install: macOS or Linux

```bash
curl -fsSL https://archon.diy/install | bash
```

### Homebrew

```bash
brew install coleam00/archon/archon
```

### Source setup

Use this when developing Archon itself or when you need unreleased features:

```bash
git clone https://github.com/coleam00/Archon.git
cd Archon
bun install
claude
```

Then ask Claude: `Set up Archon`.

Verify the CLI:

```bash
archon version
archon doctor
```

## 2. Connect the AI Provider

The packaged Ralph workflow uses the Pi provider with `anthropic/claude-sonnet-4-5` for implementation and QA nodes. Connect an Anthropic credential:

```bash
archon ai key set anthropic
```

Archon reads the key from a masked prompt. Do not place API keys in the workflow YAML or commit them to the product repository.

A supported Anthropic subscription login may be used instead:

```bash
archon ai login anthropic
```

Confirm the connection:

```bash
archon ai list
archon doctor
```

## 3. Authenticate GitHub

The workflow's sole publication node pushes the feature branch and creates a pull request with `gh`.

```bash
gh auth login
gh auth status
```

The authenticated account needs push and pull-request permissions for the product repository.

## 4. Configure Jira

Expose these variables to the Archon process. A project-local `.env` is convenient for local development, but it must remain untracked.

```bash
JIRA_BASE_URL=https://your-company.atlassian.net
JIRA_EMAIL=you@example.com
JIRA_API_TOKEN=your-atlassian-api-token
JIRA_SUBTASK_TYPE=Sub-task
```

Required Jira permissions:

- Browse and read the parent issue
- Create subtasks under the parent
- Transition child issues
- Add comments to the parent

`JIRA_SUBTASK_TYPE` is optional. Set it when your Jira project uses a localized or custom subtask issue-type name.

## 5. Install the Workflow into a Product Repository

From this `manhattan-orchestrator` checkout:

```bash
bash archon/install.sh /absolute/path/to/product-repository
```

The installer adds only:

```text
<product>/.archon/workflows/manhattan-orchestrator-v2.yaml
<product>/.archon/commands/archon-ralph-generate.md
```

It refuses to overwrite either path. If you intentionally want to replace an existing version, review the difference first, then run:

```bash
bash archon/install.sh /absolute/path/to/product-repository --force
```

The previous file is retained with a `.bak` suffix.

## 6. Validate the Installed Workflow

```bash
cd /absolute/path/to/product-repository
archon validate workflows manhattan-orchestrator-v2 --json
```

Expected result:

```json
{
  "summary": {
    "total": 1,
    "valid": 1,
    "errors": 0,
    "warnings": 0
  }
}
```

Do not run the workflow if validation reports an error.

## 7. Run from a Jira Ticket

The Jira issue is the specification. Pass only the parent issue key unless additional routing context is genuinely necessary.

```bash
cd /absolute/path/to/product-repository
archon workflow run manhattan-orchestrator-v2 \
  --branch feat/SAP-3560-voice-health \
  "SAP-3560"
```

The workflow will:

1. Fetch the parent Jira issue.
2. Decompose its acceptance criteria into risk-scored child stories.
3. Create Jira subtasks and minimal local workflow state.
4. Sync the isolated feature branch with `main` before implementation.
5. Explore interfaces before the implementation agent writes code.
6. Run build, test, browser, architecture, and scope gates.
7. Convene independent frontend, code, and architecture reviewers.
8. Push and open a PR only after the QA path clears.
9. Update Jira and emit a calibrated report.

## Monitor and Recover

```bash
archon workflow runs
archon workflow get <run-id> --verbose
archon workflow resume <run-id>
archon workflow abandon <run-id>
```

A paused or failed run must be inspected before resuming. Do not bypass a failing evidence gate merely to obtain a PR.

## Important Current Limits

The onboarding guide at [`manhattan-orchestrator-v2-onboarding.html`](manhattan-orchestrator-v2-onboarding.html) documents current hardening gaps. In particular:

- The environment gate proves toolchain and baseline build health, but project-specific service/database truth still requires project-declared probes.
- The browser gate requires content-oriented Playwright assertions, but projects should add known sentinel data plus console/network failure instrumentation.
- Jira child creation is best-effort; use deterministic story identifiers to check for duplicates before rerunning after partial failure.

## Troubleshooting

### `Unknown workflow 'manhattan-orchestrator-v2'`

Run the installer from this repository, then validate from the product repository root.

### `Unknown provider 'pi'` or credential errors

Upgrade Archon, run `archon ai list`, reconnect the Anthropic credential, and rerun `archon doctor`.

### Jira child creation fails

Check `JIRA_BASE_URL`, the configured subtask issue-type name, and the token's project permissions. Avoid manually creating duplicate subtasks until you inspect the run log.

### PR creation fails

Run `gh auth status` from the product repository and confirm the account can push the feature branch and create pull requests.
