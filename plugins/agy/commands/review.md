---
description: Dispatch a read-only adversarial review interactively to the Antigravity (agy) CLI
argument-hint: '<pre-staged diff path or explicit file list>'
disable-model-invocation: true
allowed-tools: Bash(bash:*)
---

Forward a read-only adversarial review request to `agy` directly — do not inspect the repo, answer the request yourself, or draft any answer.

Any nonzero exit, empty reply, quota, timeout, or provider/server error is terminal plugin output: report it to the caller/lead and stop. Never perform or retry the requested review in Claude.

Execute `agy` review interactively in the foreground so output streams live to the user:

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" prompt <<'AGY_EOF'
Perform a read-only adversarial review of the pre-staged diff or explicit file list at: $ARGUMENTS. Find only concrete defects. Never edit files or run commands that mutate files. Return each finding as file:line — severity — defect — fix, or PASS if clean.
AGY_EOF`

