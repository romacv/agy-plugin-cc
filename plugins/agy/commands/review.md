---
description: Dispatch a read-only adversarial review to the Antigravity (agy) CLI as a background subagent
argument-hint: '<pre-staged diff path or explicit file list>'
allowed-tools: Agent
---

Spawn the `agy:agy-prompt` subagent via the Agent tool with `run_in_background: true`:

- `subagent_type`: `agy:agy-prompt`
- `run_in_background`: `true`
- `description`: "agy review: $ARGUMENTS"
- `prompt`: `Perform a read-only adversarial review of the pre-staged diff or explicit file list at: $ARGUMENTS. Find only concrete defects. Never edit files or run commands that mutate files. Return each finding as file:line — severity — defect — fix, or PASS if clean.`

Do not inspect the repo or draft answers. On completion, present the subagent's output verbatim.
