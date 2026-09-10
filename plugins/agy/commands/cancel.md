---
description: Cancel an active agy job for this repository
argument-hint: '[job-id]'
disable-model-invocation: true
allowed-tools: Bash(bash:*)
---

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" cancel $ARGUMENTS`

Present the command output to the user as-is. Do not summarize.
