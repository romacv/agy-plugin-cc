---
description: Send a request to the Antigravity (agy) CLI and relay its answer
argument-hint: '<your request>'
allowed-tools: Bash(bash:*)
---

Send the user's request to agy in non-interactive print mode. The request text is passed on stdin (safe against quotes, newlines, and backticks):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" prompt <<'AGY_EOF'
$ARGUMENTS
AGY_EOF
```

Then relay the result:

- Exit code `0`: present agy's report to the user verbatim, then add a 1–2 line summary of what it did.
- Non-zero exit or timeout: surface the exit code and any stderr shown. Do NOT fabricate or guess an answer.

The run is logged. The user can review history and outputs later with `/agy:status`.

Notes:
- agy runs with **no permission-override flags** — it honors your own agy permission settings (`toolPermission`, `permissions`, `trustedWorkspaces`) in `~/.gemini/antigravity-cli/settings.json`, manageable via the `/permissions` command inside agy. Print mode is non-interactive, so a pending review can't be answered; agy may return an answer without performing write/run actions that need approval. Pre-authorize those in settings if you want them to run unattended.
- To pin a model, set `AGY_MODEL` in the environment (e.g. `AGY_MODEL="Claude Opus 4.6 (Thinking)"`); otherwise agy's default is used.
