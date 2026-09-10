---
description: Dispatch a request to the Antigravity (agy) CLI — background by default, --wait for foreground
argument-hint: '[--wait] [--fresh|--resume] [--model <name>] <your request>'
allowed-tools: Bash(bash:*), Agent
---

Forward the user's request to `agy` directly — do not inspect the repo, answer the request yourself, or draft any answer.

Any nonzero exit, empty reply, quota, timeout, or provider/server error is terminal plugin output: report it to the caller/lead and stop. Never perform or retry the requested work in Claude.

Raw arguments: `$ARGUMENTS`

## Execution mode

- If `--wait` is present in the arguments: run **foreground** (streaming, blocks until done):

  !`bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" prompt $ARGUMENTS`

- Otherwise (default): run **background** by spawning the `agy:agy-prompt` subagent so Claude remains free. Strip `--fresh`, `--resume`, and `--model <value>` from the text before forwarding — pass them to the subagent prompt so it can relay them to the script.

  Invoke Agent with `subagent_type: "agy:agy-prompt"` and pass the full raw arguments string verbatim as the prompt.

## Flags (forwarded to the companion script)

- `--fresh` — force a new agy project session (discard the pinned project for this repo)
- `--resume` — explicitly continue the current pinned project (default behaviour)
- `--model <name>` — override the agy model for this run

## After completion

Whenever the forwarded work changes any file, always show the user the change as a git-style +/- diff of each edited hunk (real added/removed lines), never a prose summary.
