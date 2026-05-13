# Jagged Frontier Demo

A small Claude Code prototype that makes the "jagged frontier" of AI capability visible inside the terminal. The same prompt gets a different capability verdict depending on which Claude model is active, so participants can see that capability is model-specific, not absolute.

The classifier is deliberately fake: it uses a tiny rule table, not a learned estimator. The point is the framing in the status line, not the underlying prediction.

## What it does

Two scripts wire into Claude Code:

- `classifier.sh` runs as a `UserPromptSubmit` hook. It looks at the prompt and the active model, picks a verdict from a rule table, and writes the result to `/tmp/claude-classifier-${session_id}.json`. If the verdict is medium or high risk, it surfaces a system message to the user before the model responds.
- `statusline.sh` runs as the custom status line. It reads the active model, normalizes it to Opus / Sonnet / Haiku, writes it to `/tmp/claude-model-${session_id}.txt` for the hook to read, and renders the model, context window, and capability indicator on a single line.

The two scripts share state through `/tmp` files keyed by session id, so a session in one terminal does not stomp on a session in another.

Try a prompt containing the word "refactor" on Haiku vs Opus to see the verdicts diverge.

## Requirements

- Claude Code
- `bash`, `jq`
- `npx` and Node (used to call `ccusage` for the context window segment)

## Install

1. Clone this repo somewhere stable.
2. Make the scripts executable: `chmod +x classifier.sh statusline.sh`.
3. Point Claude Code at them. The included `.claude/settings.json` does this by referencing `${CLAUDE_PROJECT_DIR}`, so opening Claude Code in this directory is enough. To use the scripts from a different working directory, copy the settings into that project's `.claude/settings.json` and replace `${CLAUDE_PROJECT_DIR}` with the absolute path to this repo.

## Files

- `classifier.sh`: prompt-submit hook, writes verdict JSON.
- `statusline.sh`: status line renderer, writes active model.
- `.claude/settings.json`: wires the hook and status line into Claude Code.

## Caveats

- The rule table covers a single trigger word and three model families. It is a teaching prop, not a capability estimator.
- State lives in `/tmp` and is cleared on reboot.
- The "Unknown" model branch fires before the status line has run once in a fresh session, which is expected.

## Context

Built for AI Kitchen sessions at Santa Clara University to give participants a concrete artifact that demonstrates the jagged-frontier idea: AI models have uneven strengths, and a tool that surfaces those gaps in context is more useful than a generic "AI can do anything" framing.
