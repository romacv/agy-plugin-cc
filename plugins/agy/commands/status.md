---
description: Show recent agy runs (history, exit codes, and log locations)
argument-hint: '[<job-id>] [--all]'
disable-model-invocation: true
allowed-tools: Bash(bash:*)
---

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" status $ARGUMENTS`

If no `<job-id>` was passed: render the command output as a single compact Markdown table of recent runs (id, started, exit, duration, prompt preview). Keep it tight — no extra prose outside the table. By default only the last 10 runs are shown; `--all` shows every recorded run. An `exit` of `stale` means the run was interrupted/crashed without recording a result.

If a `<job-id>` was passed: the command prints that single run's full log — present it as-is in a fenced block, do not summarize or condense it.
