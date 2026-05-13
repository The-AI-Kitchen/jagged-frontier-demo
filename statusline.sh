#!/bin/bash
# Custom status line for the fake-classifier prototype.
# Surfaces the three signals most relevant to "what is this model capable of right now":
#   - 🤖 active model
#   - 🧠 context window usage
#   - Capability indicator (verdict + short reason from the heuristic classifier)
# Cost and burn-rate segments from ccusage are intentionally dropped here.
#
# Reads JSON payload from Claude Code on stdin, writes a single line to stdout.

set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
state_file="/tmp/claude-classifier-${session_id}.json"
model_file="/tmp/claude-model-${session_id}.txt"

# Capture the active model so the hook can branch its verdict on it.
# Normalize to a short family name (Opus / Sonnet / Haiku) for rule-matching.
raw_model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Unknown"')
case "$raw_model" in
  *Haiku*|*haiku*)   model_short="Haiku" ;;
  *Opus*|*opus*)     model_short="Opus" ;;
  *Sonnet*|*sonnet*) model_short="Sonnet" ;;
  *)                 model_short="$raw_model" ;;
esac
printf '%s' "$model_short" >"$model_file"

# Reuse ccusage so model + context numbers stay accurate without re-implementing transcript parsing.
ccusage_out=$(echo "$input" | npx -y ccusage statusline --visual-burn-rate emoji 2>/dev/null || true)
model_seg=$(printf '%s' "$ccusage_out" | grep -oE '🤖[^|]*' | head -1 | sed 's/[[:space:]]*$//' || true)
context_seg=$(printf '%s' "$ccusage_out" | grep -oE '🧠[^|]*' | head -1 | sed 's/[[:space:]]*$//' || true)

if [ -f "$state_file" ]; then
  level=$(jq -r '.level' <"$state_file")
  verdict=$(jq -r '.verdict' <"$state_file")
  reason=$(jq -r '.reason' <"$state_file")
  case "$level" in
    high)   emoji="🔴" ;;
    medium) emoji="🟡" ;;
    low)    emoji="🟢" ;;
    *)      emoji="⚪" ;;
  esac
  if [ -n "$reason" ]; then
    capability="Capability indicator: $emoji $verdict — $reason"
  else
    capability="Capability indicator: $emoji $verdict"
  fi
else
  capability="Capability indicator: ⚪ Awaiting first prompt"
fi

parts=()
[ -n "$model_seg" ]   && parts+=("$model_seg")
[ -n "$context_seg" ] && parts+=("$context_seg")
parts+=("$capability")

out=""
for p in "${parts[@]}"; do
  if [ -z "$out" ]; then out="$p"; else out="$out | $p"; fi
done
printf '%s\n' "$out"
