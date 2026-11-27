---
name: pre-push-check
description: Run Robotalia's CI checks locally and a privacy audit of the commits about to be pushed. Use before every git push or pull request, or when asked whether a branch is ready.
---

Check that this branch is safe and ready to push. This skill only checks: do not push, commit or
fix anything unless the user asks.

## 1. Local CI
These mirror the jobs in `.github/workflows/ci.yml`. Run them all, even if one fails, so the report
is complete. The specs need PostgreSQL and Redis (`docker compose up -d --wait db redis`).

| Job | Command |
|---|---|
| lint | `bin/rubocop` |
| scan_ruby | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` |
| scan_ruby | `bin/bundler-audit` |
| scan_js | `bin/importmap audit` |
| test | `bundle exec rspec` |

A check that could not run (service down, no network) counts as **not run**, never as passed.

## 2. Privacy
1. See what would be pushed. If `origin/main` exists, the range is `origin/main..HEAD`. Otherwise
   nothing has been published yet and the scope is the whole history.
2. Run `gitleaks git --redact --no-banner` (add `--log-opts=origin/main..HEAD` when there is a
   range). If gitleaks is not installed, say so and report it as not run.
3. Start the `privacy-guard` subagent on the same scope: `diff origin/main...HEAD` or `history`.
4. Say if there are uncommitted changes: they are not part of the push and were not audited.

## 3. Report
Show a table with each check and PASS, FAIL or NOT RUN, then the failures with their output, then
privacy-guard's blockers and questions in full. End with one line: **Ready to push** only when
every check passed and privacy-guard found no blockers and left no open questions.
