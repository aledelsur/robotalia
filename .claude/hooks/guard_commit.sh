#!/bin/bash
# Claude Code PreToolUse hook for Bash: runs the privacy check before a git commit and
# refuses to force-add ignored private files. Exit 2 blocks the command.
#
# It reads the command text, so it is a safety net, not a sandbox. script/install_git_hooks
# adds the same check as a git pre-commit hook.

command=$(jq -r '.tool_input.command // empty') || {
  echo "Commit guard could not read the hook input (is jq installed?)." >&2
  exit 2
}

if grep -Eq '\bgit\b[^;&|]*\badd\b[^;&|]*[[:space:]](-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)' <<<"$command" &&
  grep -Eq '(private/|\.env|\.key\b)' <<<"$command"; then
  echo "Blocked: never force-add private/, .env or key files. This repo is public." >&2
  exit 2
fi

grep -Eq '\bgit\b[^;&|]*\bcommit\b' <<<"$command" || exit 0

options=()
if grep -Eq '\bcommit\b.*[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)' <<<"$command"; then
  options+=(--all)
fi
# This hook runs before the whole command, so files added in the same command are not staged yet.
if grep -Eq '\bgit\b[^;&|]*\b(add|stage)\b' <<<"$command"; then
  options+=(--untracked)
fi

cd "${CLAUDE_PROJECT_DIR:?}" || exit 2
script/check_staged_privacy "${options[@]}" || exit 2
