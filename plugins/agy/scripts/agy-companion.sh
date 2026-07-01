#!/usr/bin/env bash
# agy-companion.sh — thin helper for the agy Claude Code plugin.
# Subcommands:
#   setup                    Check the agy binary is installed & authed; report tool-permission.
#   prompt [--model <name>]  Read a request on stdin, run `agy -p`, log it, relay output.
#   status [<job-id>|--all]  List recent agy runs, or print one run's full log by id.
#
# Env:
#   AGY_BIN            Override the agy binary (default: agy on PATH, then common paths).
#   AGY_MODEL          Pass --model "<name>" to agy for prompt runs (default: agy's default).
#   AGY_CC_STATE_DIR   Where run logs are kept (default: ~/.claude/.agy-cc).
#   AGY_CC_KEEP        Number of run logs to retain (default: 50).
set -uo pipefail

AGY_BIN="${AGY_BIN:-agy}"
STATE_DIR="${AGY_CC_STATE_DIR:-$HOME/.claude/.agy-cc}"
JOBS_DIR="$STATE_DIR/jobs"
mkdir -p "$JOBS_DIR"

find_agy() {
  if command -v "$AGY_BIN" >/dev/null 2>&1; then command -v "$AGY_BIN"; return 0; fi
  local p
  for p in "$HOME/.local/bin/agy" "/usr/local/bin/agy" "/opt/homebrew/bin/agy"; do
    [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

# Delete all but the newest AGY_CC_KEEP job logs so the state dir can't grow unbounded.
prune_jobs() {
  local keep="${AGY_CC_KEEP:-50}" f
  # shellcheck disable=SC2012
  ls -1t "$JOBS_DIR"/*.log 2>/dev/null | tail -n +"$((keep + 1))" | while IFS= read -r f; do
    [ -n "$f" ] && rm -f "$f"
  done
}

cmd_setup() {
  local bin
  if ! bin="$(find_agy)"; then
    echo "agy: NOT INSTALLED"
    echo "The 'agy' binary was not found on PATH or in ~/.local/bin, /usr/local/bin, /opt/homebrew/bin."
    return 1
  fi
  echo "agy: installed"
  echo "path: $bin"
  # Auth / reachability check: `agy models` is non-interactive and exits 0 when signed in.
  if "$bin" models >/dev/null 2>&1; then
    echo "auth: OK"
    echo "default-model: $("$bin" models 2>/dev/null | head -1)"
    # Report the agy tool-permission mode: it alone decides whether agy may ACT
    # (write files / run commands) unattended in print mode. This plugin forces no
    # flags, so this is entirely the user's own agy setting.
    local settings="$HOME/.gemini/antigravity-cli/settings.json" tp="request-review"
    [ -f "$settings" ] && tp="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('toolPermission','request-review'))" "$settings" 2>/dev/null || echo request-review)"
    echo "tool-permission: $tp"
    case "$tp" in
      always-proceed|proceed-in-sandbox)
        echo "acts-unattended: yes ($tp)" ;;
      *)
        echo "acts-unattended: no ($tp) — agy answers but SKIPS writes/commands in print mode"
        echo "  to let agy act: run /permissions inside agy (or edit $settings) and choose"
        echo "  'always-proceed' (full) or 'proceed-in-sandbox' (sandboxed)" ;;
    esac
    echo "READY"
    return 0
  fi
  echo "auth: NOT AUTHENTICATED"
  return 2
}

cmd_prompt() {
  local bin
  if ! bin="$(find_agy)"; then
    echo "agy NOT INSTALLED — run /agy:setup first."
    return 1
  fi

  # Optional leading `--model <name>`; env AGY_MODEL is the fallback.
  if [ "${1:-}" = "--model" ] && [ -n "${2:-}" ]; then
    AGY_MODEL="$2"
  fi

  local prompt
  prompt="$(cat)"
  if [ -z "${prompt//[[:space:]]/}" ]; then
    echo "No prompt provided. Usage: /agy:prompt <your request>"
    return 1
  fi

  local ts id log first
  ts="$(date +%Y%m%d-%H%M%S)"
  id="$ts-$$"
  log="$JOBS_DIR/$id.log"
  first="$(printf '%s' "$prompt" | head -1)"
  {
    echo "# agy job $id"
    echo "# started: $(date -Iseconds 2>/dev/null || date)"
    echo "# prompt: $first"
    echo "# ---"
  } > "$log"

  local -a model_args=()
  [ -n "${AGY_MODEL:-}" ] && model_args=(--model "$AGY_MODEL")

  # Project isolation: run under OUR OWN pinned agy project — never the globally
  # most-recent one, which may belong to an unrelated repo (that cross-project bleed
  # is what makes agy wander into another workspace's task backlog and time out).
  # First run creates a fresh project (--new-project) and we remember its id; every
  # later run resumes ONLY that project (--project <id>). Continuity stays inside this
  # plugin's own agent; foreign projects can never leak in.
  local brain_dir="$HOME/.gemini/antigravity-cli/brain"
  local project_file="$STATE_DIR/project-id"
  local -a proj_args=()
  local before_dirs="" used_new=0
  if [ -s "$project_file" ]; then
    proj_args=(--project "$(cat "$project_file")")
  else
    proj_args=(--new-project); used_new=1
    before_dirs="$(ls -1d "$brain_dir"/*/ 2>/dev/null | sort)"
  fi

  local start end rc
  start="$(date +%s)"
  # NOTE: -p/--print consumes the NEXT token as the prompt, so the prompt MUST come
  # immediately after -p, with every other flag placed before it.
  "$bin" --print-timeout 5m "${proj_args[@]}" "${model_args[@]}" -p "$prompt" 2>&1 | tee -a "$log"
  rc="${PIPESTATUS[0]}"
  end="$(date +%s)"

  # After a first-time --new-project run, remember the id agy created (the brain dir
  # that appeared) so subsequent calls resume THIS project only.
  if [ "$used_new" -eq 1 ] && [ "$rc" -eq 0 ]; then
    local after_dirs newdir
    after_dirs="$(ls -1d "$brain_dir"/*/ 2>/dev/null | sort)"
    newdir="$(comm -13 <(printf '%s\n' "$before_dirs") <(printf '%s\n' "$after_dirs") | head -1)"
    [ -n "$newdir" ] && basename "$newdir" > "$project_file"
  fi
  {
    echo "# ---"
    echo "# exit: $rc"
    echo "# duration: $((end - start))s"
  } >> "$log"

  prune_jobs

  echo
  echo "[agy job $id · exit $rc · $((end - start))s · log: $log]"
  return "$rc"
}

cmd_status() {
  local all=0 want_id=""
  case "${1:-}" in
    --all) all=1 ;;
    "") ;;
    *) want_id="$1" ;;
  esac

  # Single-run inspection: /agy:status <job-id> prints that run's full log.
  if [ -n "$want_id" ]; then
    local jf="$JOBS_DIR/$want_id.log"
    if [ ! -f "$jf" ]; then echo "No such job: $want_id"; return 1; fi
    cat "$jf"
    return 0
  fi

  local logs
  # shellcheck disable=SC2012
  logs="$(ls -1t "$JOBS_DIR"/*.log 2>/dev/null || true)"
  if [ -z "$logs" ]; then
    echo "No agy runs recorded yet. Use /agy:prompt to start one."
    return 0
  fi

  echo "id | started | exit | duration | prompt"
  local count=0 f id started exitc dur prompt mtime now age
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    count=$((count + 1))
    if [ "$all" -eq 0 ] && [ "$count" -gt 10 ]; then break; fi
    id="$(basename "$f" .log)"
    started="$(grep -m1 '^# started:' "$f" | cut -d' ' -f3-)"
    exitc="$(grep -m1 '^# exit:' "$f" | cut -d' ' -f3-)"
    dur="$(grep -m1 '^# duration:' "$f" | cut -d' ' -f3-)"; dur="${dur:--}"
    if [ -z "$exitc" ]; then
      # No exit footer: recent → still running; old → crashed/interrupted (stale).
      mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
      now="$(date +%s)"; age=$(( (now - mtime) / 60 ))
      if [ "$age" -ge 6 ]; then exitc="stale"; else exitc="running"; fi
    fi
    prompt="$(grep -m1 '^# prompt:' "$f" | cut -d' ' -f3- | cut -c1-60)"
    echo "$id | $started | $exitc | $dur | $prompt"
  done <<< "$logs"
}

case "${1:-}" in
  setup)  shift; cmd_setup  "$@" ;;
  prompt) shift; cmd_prompt "$@" ;;
  status) shift; cmd_status "$@" ;;
  *) echo "usage: agy-companion.sh {setup|prompt [--model <name>]|status [<job-id>|--all]}"; exit 64 ;;
esac
