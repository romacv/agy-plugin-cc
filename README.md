# agy-plugin-cc

A small Claude Code plugin that lets you drive the **Antigravity CLI (`agy`)** — Google's agent-first terminal CLI (successor to Gemini CLI) — from inside Claude Code.

## Commands

| Command | What it does |
|---|---|
| `/agy:setup` | Checks that the `agy` binary is installed and authenticated; reports the default model. |
| `/agy:prompt <request>` | Sends your request to `agy -p` (non-interactive), relays the answer, and logs the run. |
| `/agy:status [--all]` | Shows recent `agy` runs (id, time, exit code, duration, prompt, log path). |

## Layout

```
agy-plugin-cc/
├── .claude-plugin/marketplace.json     # marketplace manifest
└── plugins/agy/
    ├── .claude-plugin/plugin.json      # plugin manifest
    ├── commands/
    │   ├── setup.md                    # /agy:setup
    │   ├── prompt.md                   # /agy:prompt
    │   └── status.md                   # /agy:status
    └── scripts/agy-companion.sh        # setup | prompt | status helper
```

## Install

Add this repo as a Claude Code plugin marketplace, then install the plugin:

```
/plugin marketplace add romacv/agy-plugin-cc
/plugin install agy@romacv-agy
```

Then restart the session and run `/agy:setup`.

(For local development, point `marketplace add` at your local checkout path instead of the GitHub slug.)

## Configuration (env)

- `AGY_BIN` — path to the `agy` binary (default: `agy` on `PATH`, then `~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin`).
- `AGY_MODEL` — pin a model for `/agy:prompt`, e.g. `"Claude Opus 4.6 (Thinking)"` (default: agy's own default). List with `agy models`.
- `AGY_CC_STATE_DIR` — where run logs are kept (default: `~/.claude/.agy-cc`).

## Notes

- `/agy:prompt` runs `agy` with `--dangerously-skip-permissions` and a 15-minute print timeout. Skip-permissions is required for unattended print mode (otherwise a permission prompt would hang the run) — it lets `agy` write files and run commands in the current directory. Use in trusted repos; scope with `AGY_MODEL`/agy's `--sandbox` as needed.
- Print mode emits no conversation ID, so per-thread resume is not exposed here. This plugin is single-shot delegate + history.
