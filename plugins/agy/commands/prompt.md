---
description: Dispatch a request to the Antigravity (agy) CLI as a background subagent
argument-hint: '<your request>'
allowed-tools: Agent
---

Spawn the `agy:agy-prompt` subagent via the Agent tool with `run_in_background: true`:

- `subagent_type`: `agy:agy-prompt`
- `run_in_background`: `true`
- `description`: "agy prompt: $ARGUMENTS"
- `prompt`: `$ARGUMENTS`

Do not inspect the repo or draft answers. On completion, present the subagent's output verbatim.
