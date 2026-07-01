#!/usr/bin/env bash
# agy-companion.sh — thin helper for the agy Claude Code plugin.
# Subcommands:
#   setup            Check that the agy binary is installed and authenticated.
#   prompt           Read a request on stdin, run `agy -p`, log it, relay output.
#   status [--all]   List recent agy runs from the local job log.
#
# Env:
#   AGY_BIN            Override the agy binary (default: agy on PATH, then common paths).
#   AGY_MODEL          Pass --model "<name>" to agy for prompt runs (default: agy's default).
#   AGY_CC_STATE_DIR   Where run logs are kept (default: ~/.claude/.agy-cc).
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
    echo "# started: $(date -Iseconds)"
    echo "# prompt: $first"
    echo "# ---"
  } > "$log"

  local -a model_args=()
  [ -n "${AGY_MODEL:-}" ] && model_args=(--model "$AGY_MODEL")

  local start end rc
  start="$(date +%s)"
  # NOTE: -p/--print consumes the NEXT token as the prompt, so the prompt MUST come
  # immediately after -p, with every other flag placed before it.
  "$bin" --print-timeout 15m "${model_args[@]}" -p "$prompt" 2>&1 | tee -a "$log"
  rc="${PIPESTATUS[0]}"
  end="$(date +%s)"
  {
    echo "# ---"
    echo "# exit: $rc"
    echo "# duration: $((end - start))s"
  } >> "$log"

  echo
  echo "[agy job $id · exit $rc · $((end - start))s · log: $log]"
  return "$rc"
}

cmd_status() {
  local all=0
  [ "${1:-}" = "--all" ] && all=1

  local logs
  logs="$(ls -1t "$JOBS_DIR"/*.log 2>/dev/null || true)"
  if [ -z "$logs" ]; then
    echo "No agy runs recorded yet. Use /agy:prompt to start one."
    return 0
  fi

  echo "id | started | exit | duration | prompt"
  local count=0 f id started exitc dur prompt
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    count=$((count + 1))
    if [ "$all" -eq 0 ] && [ "$count" -gt 10 ]; then break; fi
    id="$(basename "$f" .log)"
    started="$(grep -m1 '^# started:' "$f" | cut -d' ' -f3-)"
    exitc="$(grep -m1 '^# exit:' "$f" | cut -d' ' -f3-)"; exitc="${exitc:-running}"
    dur="$(grep -m1 '^# duration:' "$f" | cut -d' ' -f3-)"; dur="${dur:--}"
    prompt="$(grep -m1 '^# prompt:' "$f" | cut -d' ' -f3- | cut -c1-60)"
    echo "$id | $started | $exitc | $dur | $prompt"
  done <<< "$logs"
}

case "${1:-}" in
  setup)  shift; cmd_setup  "$@" ;;
  prompt) shift; cmd_prompt "$@" ;;
  status) shift; cmd_status "$@" ;;
  *) echo "usage: agy-companion.sh {setup|prompt|status}"; exit 64 ;;
esac
