---
description: Check whether the local Antigravity (agy) CLI is installed and authenticated
argument-hint: ''
allowed-tools: Bash(bash:*)
---

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agy-companion.sh" setup
```

Interpret the output for the user:

- Output contains `READY` → agy is installed and authenticated. Present the binary path, default model, and the `tool-permission:` line. If the output shows `acts-unattended: no`, relay the hint: agy will only answer (not write files or run commands) through `/agy:prompt` until the user enables `always-proceed` or `proceed-in-sandbox` via `/permissions` inside agy. If `acts-unattended: yes`, just note the current mode.
- Output contains `NOT INSTALLED` → the `agy` binary was not found. Tell the user Antigravity CLI ships as `agy` (usually at `~/.local/bin/agy`); if it exists but is not on `PATH`, advise adding `~/.local/bin` to `PATH` or running `agy install`. Do NOT attempt a package-manager install — there is no npm package.
- Output contains `NOT AUTHENTICATED` → tell the user to run `!agy` once interactively to sign in, then re-run `/agy:setup`.

Keep the reply terse. Do not run any command other than the one above.
