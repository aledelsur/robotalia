#!/bin/bash
# Claude Code PostToolUse hook for Edit and Write: lints the edited Ruby file. It only
# reports, because rewriting a file behind Claude's back breaks its next edit. Exit 2
# shows the offenses to Claude.

file=$(jq -r '.tool_input.file_path // empty')
root=${CLAUDE_PROJECT_DIR:?}

case "$file" in
  "$root"/*) ;;
  *) exit 0 ;;
esac
case "$file" in
  *.rb | *.rake | *.ru | */Gemfile) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

cd "$root" || exit 0
if ! output=$(bin/rubocop --force-exclusion --format emacs "$file" 2>&1); then
  printf 'RuboCop found problems. Fix them before going on:\n%s\n' "$output" >&2
  exit 2
fi
