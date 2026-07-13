#!/usr/bin/env bash
# agy-companion.sh — thin helper for the agy Claude Code plugin.
# Subcommands:
#   setup                    Check the agy binary is installed & authed; report tool-permission.
#   prompt [--model <name>]  Read a request on stdin, run `agy -p`, log it, relay output.
#   status [<job-id>|--all]  List recent agy runs, or print one run's full log by id.
#   result <job-id>          Print a finished run's stored reply (body only) and exit its status.
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

  local start end duration rc stdout_file stderr_file
  # Hard watchdog (pure bash — no coreutils/timeout needed): agy print mode can WEDGE —
  # a tool-permission review it can't answer non-interactively, or a long/stuck spawned
  # command (e.g. a build) — and its own --print-timeout does NOT bound those, so a job can
  # hang indefinitely (seen: 10+ min). Run agy in the background with output tee'd to the
  # log+stdout via process substitution (so $! is agy's REAL pid), and a sleeper that
  # SIGTERM/SIGKILLs agy + its children after AGY_TIMEOUT seconds (default 300 = 5m,
  # a backstop above agy's internal 4m wait).
  local agy_timeout="${AGY_TIMEOUT:-300}"
  stdout_file="$JOBS_DIR/$id.stdout"
  stderr_file="$JOBS_DIR/$id.stderr"
  start="$(date +%s)"
  # NOTE: -p/--print consumes the NEXT token as the prompt, so the prompt MUST come
  # immediately after -p, with every other flag placed before it.
  "$bin" --print-timeout 4m "${proj_args[@]}" "${model_args[@]}" -p "$prompt" > >(tee -a "$log" "$stdout_file" >/dev/null) 2> >(tee -a "$log" "$stderr_file" >&2) &
  local agy_pid=$!
  ( sleep "$agy_timeout"
    if kill -0 "$agy_pid" 2>/dev/null; then
      kill -TERM "$agy_pid" 2>/dev/null; pkill -TERM -P "$agy_pid" 2>/dev/null
      sleep 5
      kill -KILL "$agy_pid" 2>/dev/null; pkill -KILL -P "$agy_pid" 2>/dev/null
    fi ) & local wd_pid=$!
  wait "$agy_pid" 2>/dev/null; rc=$?
  kill "$wd_pid" 2>/dev/null; wait "$wd_pid" 2>/dev/null
  end="$(date +%s)"
  duration=$((end - start))
  sleep 1
  [ -s "$stdout_file" ] && cat "$stdout_file"
  if [ "$rc" -eq 143 ] || [ "$rc" -eq 137 ]; then
    rc=124
    echo "[agy-companion: HARD TIMEOUT after ${agy_timeout}s — agy hung and was killed. Print mode can't answer tool-permission reviews and doesn't bound stuck commands: set toolPermission=always-proceed for unattended writes, and keep agy tasks to edits (run long builds separately).]" | tee -a "$log"
  fi

  local quota_marker=0 empty_body=0 reset=""
  grep -Eqi 'RESOURCE_EXHAUSTED|HTTP[^0-9]*429' "$stderr_file" "$stdout_file" && quota_marker=1
  if [ "$rc" -eq 0 ] && [ "$duration" -le 15 ] && ! grep -q '[^[:space:]]' "$stdout_file"; then
    empty_body=1
  fi
  if [ "$quota_marker" -eq 1 ] && [ -s "$stdout_file" ] && ! grep -Eqi 'RESOURCE_EXHAUSTED|HTTP[^0-9]*429' "$stdout_file"; then
    quota_marker=0
  fi
  if [ "$quota_marker" -eq 1 ] || [ "$empty_body" -eq 1 ]; then
    reset="$(sed -nE -e 's/.*[Rr]esets? (in|after)[[:space:]]+([0-9][^,;.]*).*/\2/p' -e 's/.*[Rr]etry (in|after)[[:space:]]+([0-9][^,;.]*).*/\2/p' "$stderr_file" "$stdout_file" | head -1)"
    if [ -n "$reset" ]; then
      echo "agy at limit — resets in $reset" | tee -a "$log"
    else
      echo "agy returned empty output — treat as failure" | tee -a "$log"
    fi
    [ "$rc" -eq 0 ] && rc=42
  fi
  [ -s "$log" ] && rm -f "$stdout_file" "$stderr_file"

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
    echo "# duration: ${duration}s"
  } >> "$log"

  prune_jobs

  echo
  echo "[agy job $id · exit $rc · ${duration}s · log: $log]"
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

cmd_result() {
  local want_id="${1:-}"
  if [ -z "$want_id" ]; then
    echo "Usage: /agy:result <job-id>"
    return 1
  fi
  local jf="$JOBS_DIR/$want_id.log"
  if [ ! -f "$jf" ]; then echo "No such job: $want_id"; return 1; fi

  if ! grep -q '^# exit:' "$jf"; then
    local mtime now age
    mtime="$(stat -f %m "$jf" 2>/dev/null || stat -c %Y "$jf" 2>/dev/null || echo 0)"
    now="$(date +%s)"; age=$(( (now - mtime) / 60 ))
    if [ "$age" -ge 6 ]; then
      echo "Job $want_id looks stale (no exit recorded, last write ${age}m ago) — it likely crashed or was interrupted."
    else
      echo "Job $want_id is still running — no result yet."
    fi
    return 1
  fi

  # The body is everything between the first and second "# ---" marker lines.
  awk '/^# ---$/{c++; next} c==1{print}' "$jf"
  local exitc dur
  exitc="$(grep -m1 '^# exit:' "$jf" | cut -d' ' -f3-)"
  dur="$(grep -m1 '^# duration:' "$jf" | cut -d' ' -f3-)"
  echo
  echo "[job $want_id · exit $exitc · $dur]"
  [ "$exitc" = "0" ]
}

case "${1:-}" in
  setup)  shift; cmd_setup  "$@" ;;
  prompt) shift; cmd_prompt "$@" ;;
  status) shift; cmd_status "$@" ;;
  result) shift; cmd_result "$@" ;;
  *) echo "usage: agy-companion.sh {setup|prompt [--model <name>]|status [<job-id>|--all]|result <job-id>}"; exit 64 ;;
esac
