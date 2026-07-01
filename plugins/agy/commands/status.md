---
description: Show recent agy runs (history, exit codes, and log locations)
argument-hint: '[--all]'
disable-model-invocation: true
allowed-tools: Bash(bash:*)
---

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" status $ARGUMENTS`

Render the command output as a single compact Markdown table of recent runs (id, started, exit, duration, prompt preview). Keep it tight — no extra prose outside the table. Point the user at the log path for any run they want to inspect in full. By default only the last 10 runs are shown; `--all` shows every recorded run.
