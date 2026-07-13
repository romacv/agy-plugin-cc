---
description: Show the stored final output for a finished agy CLI job
argument-hint: '<job-id>'
allowed-tools: Bash(bash:*)
---

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" result $ARGUMENTS`

Present the full command output to the user. Do not summarize or condense it. Preserve all details including:
- Job id, exit code, and duration
- The complete agy reply
- Whether the job is still running or looks stale, if reported

If the run changed any files, always show the change as a git-style +/- diff of each edited hunk, not a prose summary.
