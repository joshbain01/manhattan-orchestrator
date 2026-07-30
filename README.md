# Manhattan Orchestrator

---

## The Story

In 1942, the United States launched the most ambitious engineering undertaking in human history. The Manhattan Project wasn't just a physics experiment — it was a masterclass in managing staggering complexity under conditions of radical uncertainty. Thousands of the world's brightest minds worked across multiple secret sites, each team knowing only what they absolutely needed to know. No one person held the whole picture. And yet, through rigorous decomposition, strict compartmentalization, and relentless independent verification, they succeeded.

**The Manhattan Orchestrator** brings that same project discipline to your AI-assisted engineering work.

It is a [VS Code Copilot custom skill](https://code.visualstudio.com/docs/copilot/copilot-customization) that transforms Copilot into a structured, multi-agent problem-solving system. Instead of answering a question, it runs a five-phase playbook: auditing the request for hidden assumptions, decomposing the problem into a risk-weighted dependency tree, delegating each slice to a domain specialist who sees *only their piece*, verifying results through an independent agent who had no hand in building them, and delivering a calibrated answer with every claim explicitly tagged as fact, assumption, or hypothesis.

It ships with **55 pre-built engineering specialist personas** (the Engineering Division) — each a deep-domain expert the orchestrator can spawn as a Tier 2 specialist. A Backend Architect designs the module. A Code Reviewer — who never saw the design discussion — audits it. The orchestrator arbitrates. The system does not trust itself.

---

## Why This Works

When a single LLM context window holds the full problem, the full codebase, the full history of the conversation, and the full solution — it becomes a physicist who also runs the reactor, designs the detonator, and checks their own math. Errors compound invisibly. The system gains false confidence. The output looks rigorous but isn't.

The Manhattan Orchestrator enforces need-to-know at every tier:

- The **orchestrator** coordinates but rarely touches the work directly
- Each **specialist** receives only the context required for their slice
- The **verifier** sees the output and the spec — never the reasoning that produced the output
- Every claim in the final delivery is explicitly tagged: **Verified Fact**, **Reported Fact**, **Assumption**, or **Hypothesis**

It is a system designed to *fail loudly* when assumptions are wrong, and to *surface the boundary* between what is known and what is guessed.

---

## What This Is

---

## Contents

```
manhattan-orchestrator/
├── install.sh                                   ← one-command installer
├── skills/
│   └── manhattan-orchestrator/
│       └── SKILL.md                             ← the orchestrator skill
└── agents/
    ├── engineering-software-architect.md
    ├── engineering-backend-architect.md
    ├── engineering-sre.md
    └── ... (55 total)
```

---

## Prerequisites

| Requirement | Notes |
|---|---|
| VS Code | Any recent version |
| GitHub Copilot | Chat enabled |
| `bash` | For `install.sh` |

---

## Installation

### One-command install

```bash
git clone https://github.com/jbain/manhattan-orchestrator.git
cd manhattan-orchestrator
bash install.sh
```

This will:
1. Copy `skills/manhattan-orchestrator/SKILL.md` → `~/.agents/skills/manhattan-orchestrator/SKILL.md` (with your `$HOME` path substituted in)
2. Copy all 58 `agents/engineering-*.md` files → `~/.copilot/agents/`

### Configure VS Code

Open VS Code Settings JSON (`Ctrl+,` → `Open Settings JSON`) and add:

```json
"github.copilot.chat.promptFilesLocations": [
  "~/.agents/skills"
]
```

Reload VS Code (`Ctrl+Shift+P` → `Developer: Reload Window`).

### Verify

In Copilot Chat, type `/manhattan` — it should autocomplete to `/manhattan-orchestrator`.

---

## Usage

Invoke the skill with the `/manhattan-orchestrator` command in Copilot Chat:

```
/manhattan-orchestrator I need to redesign our authentication layer to support SSO.
```

Or by describing a complex problem:

```
/manhattan-orchestrator Diagnose why our pipeline is losing ~3% of events in production
and propose a fix.
```

The orchestrator will run through its full five-phase playbook automatically:

| Phase | What happens |
|---|---|
| **1 — Request Audit** | Restates the request, surfaces ambiguities, defines the deliverable |
| **2 — Decompose & Risk Matrix** | Breaks the problem into a dependency tree with U×I risk scores |
| **3 — Delegate** | Spawns specialized sub-agents with narrow, compartmentalized context |
| **4 — Verify** | Two hard gates before any live claim — Tier A Environment Integrity (substrate liveness + DB data-truth) and Tier B Golden-Path Slice Probe (a real browser renders correct live content DB→API→pixel) — then an independent verification agent plus a risk-gated Multi-Domain QA Panel (2–3+ independent specialists must sign off) audit every load-bearing claim before "good to go" |
| **5 — Deliver** | Inverted-pyramid answer with calibrated confidence and fact tags |

---

## The Engineering Division (55 Specialists)

The orchestrator can spawn any of these specialists as Tier 2 sub-agents. Each has a full persona, domain expertise, and output contract.

| Specialist | Domain | File |
|---|---|---|
| 🏛️ Software Architect | System design, ADRs, trade-off analysis | `engineering-software-architect.md` |
| 🏗️ Backend Architect | API design, scalability, server systems | `engineering-backend-architect.md` |
| 🖥️ Frontend Developer | React/Vue/Angular, UI, Core Web Vitals | `engineering-frontend-developer.md` |
| 🤖 AI Engineer | ML models, AI pipelines, deployment | `engineering-ai-engineer.md` |
| ⚙️ DevOps Automator | CI/CD, infra automation, cloud ops | `engineering-devops-automator.md` |
| 🛡️ SRE | SLOs, error budgets, observability | `engineering-sre.md` |
| 👁️ Code Reviewer | PR review, code quality, security | `engineering-code-reviewer.md` |
| 🗄️ Database Optimizer | Schema design, query perf, indexing | `engineering-database-optimizer.md` |
| 📲 Mobile App Builder | iOS/Android, React Native, Flutter | `engineering-mobile-app-builder.md` |
| ⚡ Rapid Prototyper | Fast POCs and MVPs | `engineering-rapid-prototyper.md` |
| 💎 Senior Developer | Complex Laravel/Livewire patterns | `engineering-senior-developer.md` |
| 🌿 Git Workflow Master | Git strategy, branching, history | `engineering-git-workflow-master.md` |
| 🚨 Incident Response Commander | Incident management, post-mortems | `engineering-incident-response-commander.md` |
| 📚 Technical Writer | Developer docs, API reference | `engineering-technical-writer.md` |
| 🪡 Minimal Change Engineer | Minimum-footprint changes only | `engineering-minimal-change-engineer.md` |
| 🕸️ Multi-Agent Systems Architect | Multi-agent architecture & governance | `engineering-multi-agent-systems-architect.md` |
| 🧭 Codebase Onboarding Engineer | Onboarding to unfamiliar codebases | `engineering-codebase-onboarding-engineer.md` |
| 🔧 Data Engineer | Data pipelines, lakehouse, ETL/ELT | `engineering-data-engineer.md` |
| 🔐 Identity & Access Engineer | OAuth, SSO, SAML, OIDC | `engineering-identity-access-engineer.md` |
| 🕵️ Privacy Engineer | Privacy, PII handling, GDPR | `engineering-privacy-engineer.md` |
| 🧬 Prompt Engineer | Prompt design and LLM optimization | `engineering-prompt-engineer.md` |
| 🔍 RAG Pipeline Engineer | RAG pipelines and retrieval quality | `engineering-rag-pipeline-engineer.md` |
| 🔩 Embedded Firmware Engineer | Embedded, bare-metal, RTOS | `engineering-embedded-firmware-engineer.md` |
| ⛓️ Solidity Smart Contract Engineer | Smart contracts, DeFi, EVM | `engineering-solidity-smart-contract-engineer.md` |
| 💰 FinOps Engineer | Cloud cost optimization | `engineering-finops-engineer.md` |
| 🔌 API Platform Engineer | Public/partner API platforms | `engineering-api-platform-engineer.md` |
| ♿ Section 508 Specialist | Section 508 / accessibility | `engineering-section-508-specialist.md` |
| 🦀 Rust Refactoring Specialist | Rust refactoring at repo scale | `engineering-rust-refactoring-specialist.md` |
| 🧩 WebAssembly Engineer | WebAssembly, Wasm, Rust→browser | `engineering-webassembly-engineer.md` |
| 💳 Payments & Billing Engineer | Payments, Stripe, billing | `engineering-payments-billing-engineer.md` |
| 🔎 Search Relevance Engineer | Search, Elasticsearch, relevance | `engineering-search-relevance-engineer.md` |
| 🎬 Video Streaming Engineer | Video streaming, HLS/DASH, ABR | `engineering-video-streaming-engineer.md` |
| 🎙️ Voice AI Integration Engineer | Voice/speech pipelines, Whisper | `engineering-voice-ai-integration-engineer.md` |
| 🤝 Realtime Collaboration Engineer | Realtime collab, WebSocket, CRDTs | `engineering-realtime-collaboration-engineer.md` |
| 🌍 Internationalization Engineer | i18n, ICU MessageFormat, RTL | `engineering-i18n-engineer.md` |
| ⚡ WordPress Performance Engineer | WordPress performance / WooCommerce | `engineering-wordpress-performance.md` |
| ⚡ Drupal Performance Engineer | Drupal performance / Drupal Commerce | `engineering-drupal-performance.md` |
| 💻 Desktop App Engineer | Desktop apps (Electron/Tauri) | `engineering-desktop-app-engineer.md` |
| 🛠️ Developer Tooling Engineer | Developer tooling and CLIs | `engineering-developer-tooling-engineer.md` |
| 📡 IoT Fleet Engineer | IoT fleet, MQTT, device provisioning | `engineering-iot-fleet-engineer.md` |
| 🧪 LLM Post-Training Engineer | LLM fine-tuning, RLHF, SFT | `engineering-llm-post-training-engineer.md` |
| 🛟 Database Reliability Engineer | Database HA, replication, DBRE | `engineering-database-reliability-engineer.md` |
| 🧬 AI Data Remediation Engineer | Self-healing data pipelines | `engineering-ai-data-remediation-engineer.md` |
| 📈 Data Visualization Engineer | Data visualization, charts | `engineering-data-visualization-engineer.md` |
| ⚡ Autonomous Optimization Architect | Autonomous LLM cost/routing | `engineering-autonomous-optimization-architect.md` |
| ️ WordPress Shopping Cart Engineer | WordPress e-commerce / WooCommerce | `engineering-wordpress-shopping-cart.md` |
| 🛒 Drupal Shopping Cart Engineer | Drupal e-commerce | `engineering-drupal-shopping-cart.md` |
| 🔧 Filament Optimization Specialist | Filament PHP admin UX | `engineering-filament-optimization-specialist.md` |
|  Mobile Release Engineer | Mobile app release, signing, TestFlight | `engineering-mobile-release-engineer.md` |
| 📧 Email Intelligence Engineer | Email thread analysis and extraction | `engineering-email-intelligence-engineer.md` |
| 🏛️ USWDS Developer | USWDS / US federal design system | `engineering-uswds-developer.md` |
| 🖧 IT Service Manager | IT service management (ITIL 4) | `engineering-it-service-manager.md` |
| 🧱 CMS Developer | CMS (WordPress / Drupal) dev | `engineering-cms-developer.md` |
| 📜 OrgScript Engineer | OrgScript grammar and AST | `engineering-orgscript-engineer.md` |
| 🌐 Network Engineer | Cisco, Juniper, Palo Alto networking | `engineering-network-engineer.md` |

---

## How the Orchestrator Works

### The Three-Tier Model

```
Tier 1: Manhattan Orchestrator  (you — coordinates, audits, verifies)
           │
           ├── reads agent persona from ~/.copilot/agents/engineering-{name}.md
           │
           ▼
Tier 2: Engineering Specialist   (domain expert — owns a slice of the problem)
           │
           ▼
Tier 3: Worker Sub-Agents        (narrow-scope executors)
               • Researcher / Explorer  (read-only)
               • Implementer / Builder  (write files/code)
               • Verifier / Auditor     (tests, checks)
```

### The Five-Phase Playbook

Every request is processed through five mechanical phases, with structured output at each stage:

#### Phase 1: Request Audit
Surfaces ambiguities, explicit and implicit constraints, and defines the exact deliverable before any work begins.

#### Phase 2: Decompose & Risk Matrix
Breaks the problem into a dependency tree. Each task is scored **Uncertainty × Impact** (1–3 each). Risk score ≥ 6 requires independent validation.

#### Phase 3: Delegate to Specialists
Each task goes to exactly one specialist sub-agent with only the context it needs. No sub-agent sees the full problem.

#### Phase 4: Independent Verification
A *different* agent than the one that built the solution verifies it. The Devil's Advocate Analysis checks for opposing hypotheses before delivery.

#### Phase 5: Deliver (Inverted Pyramid)
Key answer first, then confidence level, then supporting facts, tagged as Verified Fact / Reported Fact / Assumption / Hypothesis.

---

## Deploying to Another Machine

```bash
# On the source machine — archive the repo
tar -czf manhattan-orchestrator.tar.gz manhattan-orchestrator/

# Copy to target
scp manhattan-orchestrator.tar.gz user@targethost:~

# On the target machine
tar -xzf manhattan-orchestrator.tar.gz
cd manhattan-orchestrator
bash install.sh
```

Then configure VS Code settings on the target machine as described in [Installation](#installation).

---

## Uninstall

```bash
rm -rf ~/.agents/skills/manhattan-orchestrator
rm -f ~/.copilot/agents/engineering-*.md
```

Remove the `github.copilot.chat.promptFilesLocations` entry from VS Code settings if no other skills use it.

---

## Architecture Notes

The SKILL.md references `~/.copilot/agents/` for the engineering persona files. `install.sh` automatically substitutes your actual `$HOME` path during installation so cross-user deployments work without manual editing.

If you want to store agent files in a different location, edit `AGENTS_DEST` at the top of `install.sh` before running it, and update the path in `~/.agents/skills/manhattan-orchestrator/SKILL.md` after installation.

---

## License

MIT
