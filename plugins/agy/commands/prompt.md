---
description: Dispatch a request interactively to the Antigravity (agy) CLI
argument-hint: '[-n|--new] <your request>'
disable-model-invocation: true
allowed-tools: Bash(bash:*)
---

Forward the user's request to `agy` directly — do not inspect the repo, answer the request yourself, or draft any answer.

Any nonzero exit, empty reply, quota, timeout, or provider/server error is terminal plugin output: report it to the caller/lead and stop. Never perform or retry the requested work in Claude.

Execute `agy` interactively in the foreground so output streams live to the user:

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" prompt <<'AGY_EOF'
$ARGUMENTS
AGY_EOF`

Whenever the forwarded work changes any file, always show the user the change as a git-style +/- diff of each edited hunk (real added/removed lines), never a prose summary.

