---
description: Dispatch a request to the Antigravity (agy) CLI as a background subagent
argument-hint: '<your request>'
allowed-tools: Agent
---

ALWAYS run this as a background subagent — never inline Bash.

Task sizing: agy is for small, self-contained requests that finish in a few minutes (the runtime kills runs at ~8 minutes). If the request is large, split it into narrow independent subtasks and dispatch several `agy:agy-prompt` subagents in parallel instead of one long job.

Spawn the `agy:agy-prompt` subagent via the Agent tool with `run_in_background: true`, passing the user's request verbatim as the `prompt`:

- `subagent_type`: `agy:agy-prompt`
- `run_in_background`: `true`
- `description`: a 3–5 word label (e.g. "agy prompt: <topic>")
- `prompt`: `$ARGUMENTS` (the user's request text, exactly as given)

Do NOT run `agy-companion.sh` yourself — the subagent forwards to the agy runtime. Do not inspect the repo, draft your own answer, or poll; the harness notifies you when the background subagent completes.

On completion:
- Present agy's answer (the subagent's returned text) verbatim, then add a 1–2 line summary of what it did.
- If the subagent failed, surface its error output as-is. Do NOT fabricate or guess an answer.

The run is logged. The user can review history and outputs later with `/agy:status`.

Notes:
- agy runs with **no permission-override flags** — it honors your own agy permission settings (`toolPermission`, `permissions`, `trustedWorkspaces`) in `~/.gemini/antigravity-cli/settings.json`, manageable via the `/permissions` command inside agy. Print mode is non-interactive, so a pending review can't be answered; agy may return an answer without performing write/run actions that need approval. Pre-authorize those in settings if you want them to run unattended.
- To pin a model, set `AGY_MODEL` in the environment before the subagent runs (e.g. `AGY_MODEL="Claude Opus 4.6 (Thinking)"`); otherwise agy's default is used.
