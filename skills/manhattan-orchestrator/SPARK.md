# Spark / llama.cpp Integration Recipe (Unvalidated)

**Status: documentation only, not tested.** There is no NVIDIA Spark (or
equivalent LAN inference box) available in this environment to test against.
Nothing below has been run against real hardware — treat it as a starting
recipe to adapt, not a confirmed-working configuration. It is grounded in
OpenClaw's real provider docs on this machine (`docs/providers/vllm.md`,
`docs/providers/sglang.md`, `docs/gateway/local-model-services.md`,
`docs/plugins/llama-cpp.md`), quoted below where it matters, but the
end-to-end path (Spark box → OpenClaw → a Manhattan Orchestrator sub-agent)
has not been exercised.

This is kept as a separate doc from [`OPENCLAW.md`](./OPENCLAW.md) rather than
folded into it, because it's a hardware-specific recipe (routing to a LAN
inference box) rather than an adapter for the core persona-injection pattern
that OPENCLAW.md covers — different concern, different doc.

---

## 1. There is no special "NVIDIA Spark" integration

OpenClaw has no NVIDIA-Spark-specific plugin or provider. This is entirely
about pointing OpenClaw at whatever **OpenAI-compatible inference server**
you run on the Spark box over your LAN. From OpenClaw's point of view, a
Spark running vLLM/SGLang/llama.cpp looks exactly like any other remote
OpenAI-compatible `/v1` endpoint — the same shape as pointing at a vLLM
instance on a different machine on the same network.

---

## 2. Two realistic paths

### Path A — vLLM or SGLang (recommended)

Both are bundled, first-class OpenClaw providers, both OpenAI-compatible,
and both auto-discover models when you opt in with a provider-specific API
key env var (`VLLM_API_KEY` / `SGLANG_API_KEY`). vLLM and SGLang are widely
used as high-throughput serving stacks on NVIDIA GPU hardware generally —
that framing (not a specific NVIDIA Spark endorsement, which this doc has
not verified against any NVIDIA source) is why they're the recommended
starting point here over raw `llama-server`.

Per `docs/providers/vllm.md`:

> vLLM serves open-source (and some custom) models through an
> **OpenAI-compatible** HTTP API. OpenClaw connects using the
> `openai-completions` API and can **auto-discover** models when you opt in
> with `VLLM_API_KEY`.

| Property | vLLM | SGLang |
| :--- | :--- | :--- |
| Provider id | `vllm` | `sglang` |
| API | `openai-completions` | `openai-completions` |
| Auth env var | `VLLM_API_KEY` | `SGLANG_API_KEY` |
| Default base URL (local) | `http://127.0.0.1:8000/v1` | `http://127.0.0.1:30000/v1` |

For a Spark reachable over the LAN (not localhost), set an explicit
provider config with the Spark's LAN address as `baseUrl`. Example, adapted
from the vLLM doc's "Custom base URL" section, with a placeholder LAN
hostname:

```json5
{
  agents: {
    defaults: {
      model: { primary: "vllm/your-model-id" },
    },
  },
  models: {
    providers: {
      vllm: {
        baseUrl: "http://spark.local:8000/v1",
        apiKey: "${VLLM_API_KEY}",
        api: "openai-completions",
        timeoutSeconds: 300, // generous timeout for a large local model
        models: [
          {
            id: "your-model-id",
            name: "Spark vLLM Model",
            reasoning: false,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 128000,
            maxTokens: 8192,
          },
        ],
      },
    },
  },
}
```

The same shape applies for SGLang — swap `vllm` for `sglang`, `VLLM_API_KEY`
for `SGLANG_API_KEY`, and the default port for `30000`.

Per `docs/providers/vllm.md`'s troubleshooting section: OpenClaw trusts the
configured `baseUrl` origin for loopback, LAN, and Tailscale endpoints, so a
plain `http://spark.local:8000/v1` LAN address should be reachable without
extra opt-in flags — but this has not been confirmed against a real Spark.

### Path B — raw llama.cpp (`llama-server`)

If the Spark instead runs bare `llama-server` (llama.cpp's own
OpenAI-compatible server binary) rather than vLLM/SGLang, there is no
bundled `llama-server` provider preset. Wire it up as a generic custom
provider entry the same way `docs/gateway/local-model-services.md` documents
for other custom OpenAI-compatible backends (that doc's own example is for
`inferrs`, but the shape is provider-agnostic):

```json5
{
  models: {
    providers: {
      spark: {
        baseUrl: "http://spark.local:8080/v1",
        apiKey: "spark-local",
        api: "openai-completions",
        timeoutSeconds: 300,
        models: [
          {
            id: "your-gguf-model-id",
            name: "Spark llama-server Model",
            reasoning: false,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 32768,
            maxTokens: 4096,
          },
        ],
      },
    },
  },
}
```

`spark` here is an arbitrary provider id you choose — it becomes the prefix
in model refs like `spark/your-gguf-model-id`.

**Important distinction — do not confuse this with the `llama-cpp` plugin.**
OpenClaw ships an official `@openclaw/llama-cpp-provider` plugin, but per
`docs/plugins/llama-cpp.md` it is a completely different thing:

> `llama-cpp` is the official external provider plugin for local GGUF
> embeddings. It registers embedding provider id `local` and owns the
> `node-llama-cpp` runtime dependency used by `memorySearch.provider: "local"`.

That plugin runs a GGUF **embedding** model in-process, locally, for memory
search — it is not a remote chat-completion connector and has nothing to do
with talking to a Spark over the network. The integration point for a Spark
running `llama-server` is the generic custom `models.providers.<id>` entry
above (`api: "openai-completions"` + `baseUrl` pointed at the Spark), not
the `llama-cpp` plugin.

### `localService` does not apply here

`docs/gateway/local-model-services.md` describes `models.providers.<id>.localService`,
which auto-starts/stops a local model server:

> OpenClaw does not install launchd, systemd, Docker, or any daemon for
> this. The server is a plain child process of whichever OpenClaw process
> first needed it.

That's the key line: `localService` spawns a **child process of the OpenClaw
gateway process itself**, i.e. on the *same machine* as the gateway. A Spark
is a separate networked box — OpenClaw can't spawn or stop a process running
on it. So for a Spark, skip `localService` entirely; this is just a plain
remote provider `baseUrl` pointed at whatever is already running on the
Spark (vLLM, SGLang, or llama-server), with no auto-start/stop management by
OpenClaw. If you want the Spark's server started/stopped automatically,
that has to be handled outside OpenClaw (e.g. on the Spark itself, or via
whatever process manager runs there).

---

## 3. Routing orchestrator-tier work to the Spark

Once a Spark provider is wired up (Path A or B above), there are three ways
to route Manhattan Orchestrator work to it, in increasing order of
granularity:

1. **All sub-agent work** — point `agents.defaults.subagents.model` at the
   Spark provider (e.g. `"vllm/your-model-id"` or `"spark/your-gguf-model-id"`).
   This routes every Tier 2/3 sub-agent spawned via `sessions_spawn` to the
   Spark by default, while the main orchestrator session keeps using
   whatever `agents.defaults.model.primary` is set to.
2. **Per-persona override** — pass an explicit `model:` argument on
   individual `sessions_spawn` calls (see [`OPENCLAW.md`](./OPENCLAW.md) §2
   for the full `sessions_spawn` contract) when only specific personas
   should run on the Spark rather than all sub-agents.
3. **Fallback-chain entry** — add the Spark model as a fallback below the
   cloud primary (`agents.defaults.model.fallbacks` or
   `openclaw models fallbacks add spark/your-gguf-model-id`), so it's only
   used if the primary cloud model fails or is rate-limited, rather than
   being the default route.

None of these three has been exercised against real hardware — they follow
directly from how `agents.defaults.subagents.model`, `sessions_spawn`'s
`model` param, and the fallback list already work elsewhere in this repo's
OpenClaw wiring (see `install.sh`'s `provision_openrouter_models` for a
working example of the same fallback-list and `subagents.model` mechanics,
applied to OpenRouter free models instead of a Spark).
