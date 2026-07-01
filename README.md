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

## Configuration (env)

- `AGY_BIN` — path to the `agy` binary (default: `agy` on `PATH`, then `~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin`).
- `AGY_MODEL` — pin a model for `/agy:prompt`, e.g. `"Claude Opus 4.6 (Thinking)"` (default: agy's own default). List with `agy models`.
- `AGY_CC_STATE_DIR` — where run logs are kept (default: `~/.claude/.agy-cc`).

## Permissions

The plugin passes **no permission-override flags** and never forces auto-approve. Whether agy may act unattended (write files, run commands) in print mode is governed entirely by *your own* agy setting `toolPermission` in `~/.gemini/antigravity-cli/settings.json`:

- `request-review` (default) — agy answers but **skips** write/run actions in non-interactive print mode.
- `proceed-in-sandbox` — agy acts without prompting, confined to a sandbox.
- `always-proceed` — agy acts without prompting, unsandboxed.

To let agy do work through `/agy:prompt`, enable it yourself: run `/permissions` inside `agy` (or edit `settings.json`) and pick `always-proceed` or `proceed-in-sandbox`. `/agy:setup` reports your current mode.

## Notes

- `/agy:prompt` runs `agy` in print mode with a 5-minute timeout. See [Permissions](#permissions) for what agy is allowed to do.
- Print mode emits no conversation ID, so per-thread resume is not exposed here. This plugin is single-shot delegate + history.
