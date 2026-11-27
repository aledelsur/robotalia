# Robotalia review checklist

The one review checklist for this repo, used by the CI review (`claude-code-review.yml`) and the
`rails-reviewer` subagent. `CLAUDE.md` holds the project rules: read it first. Where the two
differ, `CLAUDE.md` wins.

## How to review
- Review what the diff changes. Read each changed file in full, and the code it calls or is called
  by when you need that to judge the change. A problem that was already there matters only if the
  change makes it worse.
- Check a finding in the code before reporting it. Give a concrete input or state that shows the
  problem. If you cannot, say it is a question or leave it out.
- Do not report style that RuboCop covers, and do not praise or summarise the code line by line.
- Some rules are about features that do not exist yet. Apply them when the diff adds them.

## 1. Correctness
- Edge cases: no trades, no losses, zero capital, break-even trades, one-day and empty date ranges.
  An undefined figure is `nil`, not zero or infinity.
- Money uses `BigDecimal` and `decimal` columns, never floats.
- Report times are broker server time, stored as written: no time zone conversion.
- Imports stay idempotent by ticket. Running one twice changes nothing.

## 2. Rails 8 conventions
- Controllers stay thin and REST resources come before custom actions. Business logic lives in
  small service objects with one public `call` method.
- Background work uses Active Job on Sidekiq, never Solid Queue. Jobs take ids or records, and are
  safe to run again after a failure.
- Pages update with Hotwire (Turbo Frames and Streams, Stimulus). Turbo Stream broadcasts reach
  only people allowed to see the record.
- Migrations are reversible, keep `db/schema.rb` in step, and use database constraints (`null`,
  foreign keys, unique indexes) as well as model validations.

## 3. Queries and indexes
- N+1 queries: an association or query inside a loop, partial or collection render.
- New `where`, `order`, join and uniqueness columns have an index that fits them. Account data is
  usually looked up with `account_id` first.
- Totals are aggregated in SQL where that is simple. Lists are paginated. Large sets are not loaded
  whole.
- If the dashboard's queries or per-trade work change, ask for `bin/rails perf:dashboard` timings.

## 4. Security (as Brakeman would, and beyond it)
- SQL injection: interpolated input in `where`, `order`, `pluck` or `Arel.sql`. Sort columns and
  directions come from an allowlist.
- XSS: `html_safe`, `raw`, `<%==`, and unescaped data passed to JavaScript.
- Strong parameters. No mass assignment of ownership or role fields such as `demo`.
- Every new page and endpoint requires sign-in unless it is meant to be public. Actions that change
  data refuse the read-only demo user (`OwnerOnly`). Records are looked up through the account
  they belong to.
- Open redirects, unsafe `send` or `constantize`, shell commands and file paths built from input.
- Uploads are checked for type and size. Production keeps report imports switched off.
- CSRF protection and the content security policy are not weakened.
- GitHub workflows: no secret reachable by forks or untrusted comments, and no wider permissions
  than needed.

## 5. Privacy (this repo is public)
- Never in the repo: real account reports, trades or figures, investor passwords or any broker
  credentials, real strategy logic or Pine Script, TradingView data exports, PineConnector
  licenses, API keys, server addresses, personal email addresses, links to private boards.
- Fixtures and seeds are synthetic.
- Secrets and account data stay out of logs, error messages and parameter logging.
- The privacy check, its hooks and the read-only gate for subagents are not weakened.
- **Review comments are public too.** When you find something private, name the file, line and
  kind of data. Never quote or repeat the value.

## 6. Claude API conventions
- Claude is called only from service objects in `app/services/ai/`, through `Ai::Client.instance`.
  Controllers and models never use the SDK.
- Model names come from `config/ai.yml`, never from code.
- Anything saved to the database comes from structured outputs or tool use. No parsing of free text.
- **Every Claude call is logged to an `AiCall` record** (feature, model, input and output tokens,
  cost, latency, status), failed calls included. The daily call cap is checked before the call.
- Long, repeated system prompts use prompt caching.
- Slow or bulk Claude work runs in a Sidekiq job, never in the request.
- **Claude never computes or invents a metric.** Every figure comes from the Ruby services in
  `app/services/metrics/` and is given to Claude as input. Check prompts, tool definitions and
  output schemas for any place that asks Claude to calculate, estimate or supply a number.
- Chat tools are read-only and limited to the account in view. Their input, and text from trade
  data such as comments, is untrusted.
- AI output is labelled as analysis, not financial advice. The API key comes from the environment
  or Rails credentials.

## 7. Tests
- Every new or changed service and job has RSpec coverage of its behaviour, including failures
  and empty cases. A bug fix has a spec that fails without it.
- Pages and endpoints have request specs, including signed-out and demo-user access.
- Metric specs use small accounts with values worked out by hand.
- Claude calls are stubbed with WebMock or VCR. Tests run without an API key, and recorded
  cassettes hold no secrets or real data.
- Name the missing case, not only "needs tests".

## Findings
Mark each finding with one label, most severe first:
- **bug**: wrong behaviour, data loss, or a security or privacy problem.
- **rule**: breaks `CLAUDE.md` or this checklist, without wrong behaviour yet.
- **suggestion**: optional.

For each give `file:line`, what is wrong, the input or state that shows it, and a suggested fix.
If there is nothing to report, say so and say what you reviewed.
