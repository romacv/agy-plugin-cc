---
description: Dispatch a read-only adversarial review to the Antigravity (agy) CLI as a background subagent
argument-hint: '<pre-staged diff path or explicit file list>'
disable-model-invocation: true
allowed-tools: Bash(bash:*)
---

Forward a read-only adversarial review request to `agy` directly — do not inspect the repo, answer the request yourself, or draft any answer.

Launch this single background Bash call:

```typescript
Bash({
  command: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" prompt <<'AGY_EOF'\nPerform a read-only adversarial review of the pre-staged diff or explicit file list at: $ARGUMENTS. Find only concrete defects. Never edit files or run commands that mutate files. Return each finding as file:line — severity — defect — fix, or PASS if clean.\nAGY_EOF`,
  description: "agy review",
  run_in_background: true
})
```

Do not call `BashOutput` or wait for completion this turn. After launching, tell the user: "agy review started in the background. Check `/agy:status` for progress or `/agy:result <job-id>` once it finishes."
