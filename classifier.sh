#!/bin/bash
# Fake capability classifier for Claude Code UserPromptSubmit hook.
# Multi-model demo: rule outcomes branch on the active model so participants see
# that capability is model-specific, not absolute.
#
# Reads the active model from /tmp/claude-model-${session_id}.txt (written by statusline.sh).
# Falls back to "Unknown" if the file isn't there yet (e.g. before the first refresh).
#
# State written to /tmp/claude-classifier-${session_id}.json:
#   { level, verdict, reason, rationale, model }

set -euo pipefail

input=$(cat)
prompt=$(jq -r '.prompt' <<<"$input")
session_id=$(jq -r '.session_id // "unknown"' <<<"$input")
state_file="/tmp/claude-classifier-${session_id}.json"
model_file="/tmp/claude-model-${session_id}.txt"

if [ -f "$model_file" ]; then
  model=$(cat "$model_file")
else
  model="Unknown"
fi

# Rule table. Each branch sets level/verdict/reason/rationale.
# Same trigger ("refactor") deliberately yields different verdicts on Haiku vs Opus
# so the demo surfaces the jagged-frontier point.
if echo "$prompt" | grep -iqE '\brefactor\b'; then
  case "$model" in
    Haiku)
      level="high"
      verdict="Likely to struggle"
      reason='matched "refactor"'
      rationale='Haiku has limited cross-file reasoning and a smaller working context. Multi-file refactoring is a consistent weak spot — it tends to drop imports, miss call sites, and break type signatures. For this task, switching to Opus or scoping the change to a single file with explicit context is the safer move.'
      ;;
    Opus)
      level="medium"
      verdict="Mixed outlook"
      reason='matched "refactor"'
      rationale='Opus handles scoped refactors competently but can drift on codebase-wide changes — losing invariants, adopting inconsistent style across files, or missing edge cases. Ask for a written plan first, narrow the scope to a directory or pattern, or specify which conventions must be preserved.'
      ;;
    *)
      level="high"
      verdict="Likely to struggle"
      reason='matched "refactor"'
      rationale='Refactoring is a known weak spot for AI coding agents in general. The active model is unknown, so this is the conservative verdict — set the model in the status line for a more model-specific assessment.'
      ;;
  esac
else
  level="low"
  verdict="Likely to succeed"
  reason=""
  rationale="No known weak-spot patterns matched this prompt for ${model}. Heuristics catch only specific failure modes, so the model can still struggle on novel, large-scope, or ambiguous tasks even when nothing is flagged."
fi

jq -n \
  --arg level "$level" \
  --arg verdict "$verdict" \
  --arg reason "$reason" \
  --arg rationale "$rationale" \
  --arg model "$model" \
  '{level: $level, verdict: $verdict, reason: $reason, rationale: $rationale, model: $model}' \
  >"$state_file"

if [ "$level" = "high" ] || [ "$level" = "medium" ]; then
  msg="[Capability indicator on ${model}] ${verdict}"
  [ -n "$reason" ] && msg="${msg} (${reason})"
  msg="${msg}

Why: ${rationale}"
  jq -n --arg m "$msg" '{systemMessage: $m}'
fi
