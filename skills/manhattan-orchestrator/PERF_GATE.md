# Performance & Scalability Gate (reference — loaded on demand from SKILL.md § 8)

A formal, opt-in audit protocol that systematically surfaces browser-side render
costs, memory leaks, and bundle bloat before they reach production.

**Invoke:** `/perf-gate` or "run the perf gate on `<app>`".

**When to invoke:**
- A PR is approaching merge and involves a React SPA, live data pipeline, or long-lived browser session
- A user reports the app feels sluggish, memory grows over a shift, or the initial load is slow
- The Wayfinder map's destination is production-readiness and no perf review has been run

**When NOT to invoke:**
- The change is purely backend (Python, database schema, infra config)
- The change is a documentation or config-only update
- A perf gate has already run within the current PR/effort cycle

## Flow

```
invoke: /perf-gate
          │
          ▼
   P1  Baseline (terminal — RSS/CPU snapshot)
          │
          ▼
   P2  Parallel audits (3 subagents, simultaneous, read-only)
      A: React render analyst      B: Memory leak hunter      C: Bundle & data efficiency
          │
          ▼
   P3  Independent verifier (Code Reviewer, blind to A/B/C) — eliminate refuted claims
          │
          ▼
   P4  Synthesis — risk-ranked table + "what is NOT a problem" section
          │
          ▼
   P5  Tickets → Wayfinder map → frontier declaration
```

## P1 — Baseline Measurement (always first, always AFK)

```bash
# Process RSS and CPU at idle
ps aux | grep "[v]ite\|[n]ode.*app" | awk '{printf "PID:%s RSS:%sMB CPU:%s%%\n", $2, $6/1024, $3}'

# Top memory consumers on the machine
ps aux --sort=-%mem | head -12 | awk 'NR>1 {printf "%-24s RSS:%sMB CPU:%s%%\n", $11, $6/1024, $3}'
```

Record as `[State Tag] Vite RSS / CPU: [Verified Fact]`. If the server-side process is
already lean (< 50 MB RSS, < 1% CPU at idle), the problem space is browser-side — proceed to P2.

## P2 — Parallel Domain Audits (exactly 3 simultaneous read-only subagents)

Pass each subagent only its own scope — never the full codebase or another agent's findings.

| Subagent | Persona | Scope | Mandate |
|---|---|---|---|
| **A — React Render Analyst** | Frontend Developer | `src/` — components, pages, hooks, data providers | Context blast radius; tick/polling re-render rate; `useMemo`/`useCallback`/`React.memo` discipline; unstable inline chart props; selector pattern vs. full-object subscription |
| **B — Memory Leak Hunter** | Code Reviewer | `src/hooks/`, `src/data/`, `src/components/`, files matching `setInterval\|addEventListener\|IntersectionObserver\|ResizeObserver\|AbortController\|WebSocket\|EventSource` | Cat. A missing cleanup; Cat. B unbounded growth; Cat. C stale closures; Cat. D browser global leaks |
| **C — Bundle & Data Efficiency Analyst** | Frontend Developer | `vite.config.js`, `package.json`, import graph, live data fetch logic | Code splitting (`React.lazy`); heavy-lib isolation; `manualChunks`/`chunkSizeWarningLimit`; polling cadence/payload size; context `useMemo` dep breadth |

**Output format (all three):** one finding per section — Severity (Critical/High/Medium/Low),
file path + line range, root cause/mechanism, quantified impact, recommended fix.

## P3 — Independent Verification (Code Reviewer, blind to A/B/C)

Extract the top 8-10 highest-severity claims and hand them — with file paths only, not the
specialists' framing — to a fresh Code Reviewer subagent:

```
You are an independent code auditor. Spot-check the top claims by reading the actual
source files. Do NOT trust the specialists — verify each claim against the code.
For each: state CONFIRMED / REFUTED / PARTIALLY TRUE, show the confirming/refuting
snippet, and if refuted, state what the code actually does.
```

Any claim the verifier **refutes** is eliminated before delivery (Double-Blind rule
applied to performance analysis). Record as `[State Tag] Claim N: [Verified Fact]`
(confirmed) or `[Verified Fact — ELIMINATED]` (refuted).

## P4 — Synthesis and Risk Ranking

```markdown
| Tier | # | Finding | Files | Risk | Fix Summary |
|:-----|:--|---------|-------|:----:|:------------|
| Critical | C1 | ... | ... | 9 | ... |
| High | H1 | ... | ... | 6 | ... |
| Medium | M1 | ... | ... | 4 | ... |
```

| Tier | Typical findings |
|---|---|
| Critical | No code splitting, no `React.memo`, missing build config |
| High | Independent poll intervals, unstable prop objects defeating memo, unaborted fetch closures |
| Medium | Dead tick subscriptions, listener cleanups, small dep-array bugs, unbounded state arrays |
| Low / Correctness | Single-line fixes, stale closure artifacts, eslint-suppress removals |

Always include **"What is NOT a problem"** — findings the verifier refuted, or areas
where the P1 baseline confirms the server-side process is lean. Prevents false urgency.

## P5 — Ticket Generation and Wayfinder Registration

1. One implementation-ready ticket per finding (`Title / Problem / Expected Behavior /
   Implementation Requirements / Acceptance Criteria / Data Sources / Do Not / Notes for
   Coding Agent`).
2. Dependency order for React SPA perf: `Build config → Lazy loading → Stable prop objects
   → React.memo → Context split`. Memory-leak and dep-array fixes are independent —
   parallelizable.
3. Register to the active Wayfinder map (number sequentially from its last ticket; wire
   blocking edges in a second pass once IDs exist).
4. State the frontier explicitly — which tickets are unblocked now, which are blocked and why.

**Gate output contract:** a risk-ranked findings table, a "not a problem" section, N
implementation-ready tickets, and a clear frontier statement. The gate produces decisions
and tickets — it does not implement fixes.
