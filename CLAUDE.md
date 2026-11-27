# Robotalia

Robotalia – AI operations for trading robots.

Robotalia is an AI-powered performance dashboard for trading accounts run by trading robots.
The owner imports the trade history of a MetaTrader 5 account (exported report). Robotalia
computes performance metrics (equity curve, drawdown, win rate, profit factor, breakdowns by symbol
and robot), shows them in a fast Hotwire dashboard, and uses Claude to analyse performance and answer
questions about the account in plain language.

First milestone: a deployed demo within 4 days. Prefer a smaller, polished scope over unfinished features.

It is a portfolio project: code quality, tests and a clear README matter as much as features.
The full roadmap is in `docs/PLAN.md`. Read it before starting a new phase.

## Stack
- Ruby 3.4.13, Rails 8.1 (full-stack, Hotwire: Turbo + Stimulus, Tailwind)
- PostgreSQL 16
- Redis + Sidekiq for background jobs (sidekiq-cron for scheduled jobs). Do NOT use Solid Queue.
- Official Anthropic Ruby SDK: `gem "anthropic"` (https://platform.claude.com/docs/en/api/sdks/ruby)
- Admin: Avo (free tier only; custom pages are plain Rails)
- RSpec, FactoryBot, WebMock/VCR for tests
- Docker + docker compose for local dev; Kamal 2 for deployment
- GitHub Actions for CI (RSpec + RuboCop + Brakeman)

## Claude API conventions
- All Claude calls go through service objects in `app/services/ai/` (e.g. `Ai::PerformanceAnalyst`).
  Controllers and models never call the SDK directly.
- One shared client: `Ai::Client.instance` (Anthropic::Client is thread-safe; create it once).
- Models: `claude-sonnet-5-5` for reasoning/analysis, `claude-haiku-5-5` for cheap extraction.
  Keep model names in `config/ai.yml`, never hard-coded in services.
- Use structured outputs / tool use for anything saved to the database. Never parse free text.
- Every Claude call is logged to an `AiCall` record: feature, model, input/output tokens,
  cost, latency, status. The usage page shows cost per feature.
- Use prompt caching for long, repeated system prompts.
- Slow or bulk Claude work runs in Sidekiq jobs, never in the request cycle.
- Claude explains and recommends; it never invents numbers. Every metric shown comes from
  Robotalia's own calculations, and Claude receives those numbers as input.
- API key comes from `ANTHROPIC_API_KEY` (Rails credentials in production). Never commit secrets.

## Later: backtesting optimizer
A settings optimizer for Pine Script strategies may be added later (see docs/PLAN.md). It must never
connect to TradingView (TradingView forbids automation and external optimization); TradingView data
only enters through files the owner exports manually. Not part of the first milestone.

## Coding standards
- Small, focused service objects with a single public `call` method.
- Every service and job has RSpec coverage. Claude calls are stubbed in tests (WebMock/VCR);
  tests must run without an API key.
- RuboCop (rubocop-rails-omakase) must pass.
- Commit in small steps with clear messages.

## Workflow
- Once the repo is on GitHub, every change goes through a pull request: branch from `main`, push,
  open the PR and merge it when the CI checks are green. Never push to `main`.
- Run `/pre-push-check` before every push and pull request.
- Trello: the board is named "Robotalia" (find it by name with the Trello MCP tools; its link stays
  out of this repo). When a step's pull request is opened, move its card to the Review list. When
  the pull request is merged, move the card to Done. A commit alone does not move a card. If no card
  matches a step, say so; create one only when asked. Never copy real account figures into a card.

## Claude Code setup
Shared configuration lives in `.claude/` (`settings.local.json` is personal and ignored).
- Hooks: RuboCop reports on every Ruby file Claude edits. Before a commit,
  `script/check_staged_privacy` blocks private files and secrets. `script/install_git_hooks` runs
  the same check on commits made outside Claude. If it blocks a commit, remove the private data;
  never bypass the check.
- Subagents (read-only): `rails-reviewer` reviews a diff against these rules, `privacy-guard`
  audits a diff or the whole history.
- Skills: `/pre-push-check` and `/add-metric <name> <definition>`.

## Domain language
- Account: one trading account (broker, server, currency, initial balance). The demo account is synthetic.
- AccountImport: one uploaded MT5 report, with stats (new, updated, skipped, errors).
- Deal / Trade: one executed deal or closed position from MT5 (ticket, symbol, side, volume, times,
  prices, SL/TP, commission, swap, profit, comment/magic number). Imports are idempotent by ticket.
- BalanceOperation: deposit, withdrawal or other non-trading balance change.
- Robot: the trading robot a trade belongs to, identified by comment or magic number.
- Metrics: computed by tested Ruby services, never by Claude. Claude receives metrics as input.
- AccountSync (later): adapter interface for live, read-only account access.

## Privacy
This repo is public. Never commit: real account reports or trades, investor passwords or any broker
credentials, real strategy logic or Pine Script, TradingView data exports, PineConnector licenses. Uploaded files and imported bars
stay in the local database/storage. Test fixtures and seeds use synthetic data only.
