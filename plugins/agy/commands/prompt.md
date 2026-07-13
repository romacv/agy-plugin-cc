---
description: Dispatch a request to the Antigravity (agy) CLI as a background subagent
argument-hint: '<your request>'
disable-model-invocation: true
allowed-tools: Bash(bash:*)
---

Forward the user's request to `agy` directly — do not inspect the repo, answer the request yourself, or draft any answer.

Launch this single background Bash call:

```typescript
Bash({
  command: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" prompt <<'AGY_EOF'\n$ARGUMENTS\nAGY_EOF`,
  description: "agy prompt",
  run_in_background: true
})
```

Do not call `BashOutput` or wait for completion this turn. After launching, tell the user: "agy prompt started in the background. Check `/agy:status` for progress or `/agy:result <job-id>` once it finishes."

Whenever the forwarded work changes any file, always show the user the change as a git-style +/- diff of each edited hunk (real added/removed lines), never a prose summary.
