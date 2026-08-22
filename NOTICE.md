# Third-Party Notices

This repository vendors 91 agent persona files (all files under `agents/`,
`agents/design/`, `agents/product/`, and `agents/marketing/` except
`agents/manhattan-orchestrator.md` itself) verbatim from:

**[agency-agents](https://github.com/msitarzewski/agency-agents)** by
msitarzewski and contributors ("AgentLand Contributors"), a much larger
collection (270+ personas across 17 domain divisions) of which this repo
vendors a curated engineering/design/product/marketing subset. The Marketing
Division specifically excludes agency-agents' China-domestic-platform
specialists (Baidu, Bilibili, Douyin, Kuaishou, WeChat, Weibo, Xiaohongshu,
Zhihu, and similar) — the same curation precedent already applied to the
Engineering Division (which excludes Feishu, WeChat, and GaussDB personas).

- Source repository: https://github.com/msitarzewski/agency-agents
- Synced from commit: `ebe9c99acb5c96f9468de368d8bead775387d1a7` (2026-08-06)
- License: MIT (full text below)
- File-by-file mapping of local path → upstream path: [`agents/UPSTREAM.manifest.tsv`](agents/UPSTREAM.manifest.tsv)
- Sync tooling: [`scripts/sync-agents.sh`](scripts/sync-agents.sh)

The Manhattan Orchestrator itself — the five-phase playbook, verification
gates, and `skills/manhattan-orchestrator/` — is original work by this
repo's authors and is not derived from agency-agents. Only the persona
files listed above are vendored third-party content.

---

## agency-agents license (MIT)

```
MIT License

Copyright (c) 2025 AgentLand Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
