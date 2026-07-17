# agy-plugin-cc

A small Claude Code plugin that lets you drive the **Antigravity CLI (`agy`)** — Google's agent-first terminal CLI (successor to Gemini CLI) — from inside Claude Code.

> **Autonomous edits require opting the CLI in.** By default `agy` answers `/agy:prompt` requests but skips writing files or running commands. See [Permissions](#permissions) for the one-time `agy` setting that enables it.

## Commands

| Command | What it does |
|---|---|
| `/agy:setup` | Checks that the `agy` binary is installed and authenticated; reports the default model. |
| `/agy:prompt <request>` | Forwards your request straight to `agy -p` (non-interactive) as a backgrounded run, and logs it. |
| `/agy:review <diff-path-or-files>` | Forwards a read-only adversarial review to `agy` as a backgrounded run; it reports defects or `PASS`. |
| `/agy:status [<job-id>\|--all]` | Lists recent `agy` runs (id, time, exit, duration, prompt); pass a `<job-id>` to print that run's full log. |
| `/agy:result <job-id>` | Prints a finished run's stored reply once `/agy:prompt` or `/agy:review` completes in the background. |

`/agy:prompt` and `/agy:review` call the companion script directly via a backgrounded `Bash` call — there is no LLM subagent hop in between, so forwarding is deterministic and can't be skipped.

## Layout

```
agy-plugin-cc/
├── .claude-plugin/marketplace.json     # marketplace manifest
└── plugins/agy/
    ├── .claude-plugin/plugin.json      # plugin manifest
    ├── commands/
    │   ├── setup.md                    # /agy:setup
    │   ├── prompt.md                   # /agy:prompt
    │   ├── review.md                   # /agy:review
    │   ├── status.md                   # /agy:status
    │   └── result.md                   # /agy:result
    └── scripts/agy-companion.sh        # setup | prompt | status | result helper
```

## Install

Add this repo as a Claude Code plugin marketplace, then install the plugin:

```
/plugin marketplace add romacv/agy-plugin-cc
/plugin install agy@romacv-agy
```

Then restart the session and run `/agy:setup`.

## Configuration

All optional — the plugin works out of the box: it finds `agy` automatically and uses your default model.

- `AGY_MODEL` — use a specific agy model, e.g. `"Claude Opus 4.6 (Thinking)"` (see `agy models`).

Advanced (rarely needed): `AGY_BIN` (override the binary path), `AGY_CC_STATE_DIR` (log location), `AGY_CC_KEEP` (run logs to keep, default 50).

## Permissions

The plugin passes **no permission-override flags** and never forces auto-approve. Whether agy may act unattended (write files, run commands) in print mode is governed entirely by *your own* agy setting `toolPermission` in `~/.gemini/antigravity-cli/settings.json`:

- `request-review` (default) — agy answers but **skips** write/run actions in non-interactive print mode.
- `proceed-in-sandbox` — agy acts without prompting, confined to a sandbox.
- `always-proceed` — agy acts without prompting, unsandboxed.

To let agy do work through `/agy:prompt`, enable it yourself: run `/permissions` inside `agy` (or edit `settings.json`) and pick `always-proceed` or `proceed-in-sandbox`. `/agy:setup` reports your current mode.

## Notes

- `/agy:prompt` runs `agy` in print mode with a 5-minute timeout. See [Permissions](#permissions) for what agy is allowed to do.
- Continuity is automatic, not per-job: agy has no per-job session model, so this plugin pins ONE agy project on first run and every subsequent `/agy:prompt` / `/agy:review` auto-continues it. There is no separate `resume <job-id>` command — there is only one ongoing project to resume.

## License

MIT — see [LICENSE](LICENSE).
