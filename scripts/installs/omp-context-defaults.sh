#!/usr/bin/env bash

# Restore OMP context-management defaults that are not part of the
# cosmetics-only preferences template (scripts/installs/omp-preferences.yml).
#
# compaction.thresholdTokens=272000 makes OMP summarize a session's context
# before it crosses two separate cliffs:
#   - GPT-5.6 family models (Luna/Sol/Terra) roughly double their per-token
#     price above 272,000 input tokens (see each model's `cost.longContext`
#     entry); the unset default lets a session drift to ~85% of its raw
#     context window before compaction ever fires, well past that threshold.
#   - "Context rot": recall accuracy degrades as token count grows, well
#     within the advertised context window
#     (https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents).
#
# This is a single global knob (all models share it), not a per-model
# override, and it is intentionally kept separate from the closed,
# UI-only preferences allowlist in omp-preferences.yml/omp-preferences.py.
#
# This file remains Bash 3 compatible for the Bash shipped by macOS.

set -o pipefail

THRESHOLD_TOKENS=272000

if ! command -v omp >/dev/null 2>&1; then
	printf '%s\n' "omp is not installed; skipping context-default restore." >&2
	exit 0
fi

current="$(omp config get compaction.thresholdTokens 2>/dev/null)"
if [ "$current" = "$THRESHOLD_TOKENS" ]; then
	printf '%s\n' "compaction.thresholdTokens already ${THRESHOLD_TOKENS}."
	exit 0
fi

if omp config set compaction.thresholdTokens "$THRESHOLD_TOKENS" >/dev/null; then
	printf '%s\n' "Set compaction.thresholdTokens = ${THRESHOLD_TOKENS} (was: ${current:-unset})."
else
	printf '%s\n' "Failed to set compaction.thresholdTokens." >&2
	exit 1
fi
