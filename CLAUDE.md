# Robotalia

Robotalia is an AI operations platform for trading robots (automated trading systems). It reads backtest
screenshots with Claude vision, journals live trades, watches drawdown, explains
strategy changes, and lets the owner ask questions about their trading data in plain language.

It is a portfolio project: code quality, tests and a clear README matter as much as features.
The full roadmap is in `docs/PLAN.md`. Read it before starting a new phase.

## Stack
- Ruby 3.4.13, Rails 8.1 (full-stack, Hotwire: Turbo + Stimulus, Tailwind)
- PostgreSQL 16 (+ pgvector from phase 3)
- Redis + Sidekiq for background jobs (sidekiq-cron for scheduled jobs). Do NOT use Solid Queue.
- Official Anthropic Ruby SDK: `gem "anthropic"` (https://platform.claude.com/docs/en/api/sdks/ruby)
- Admin: Avo
- RSpec, FactoryBot, WebMock/VCR for tests
- Docker + docker compose for local dev; Kamal 2 for deployment
- GitHub Actions for CI (RSpec + RuboCop + Brakeman)

## Claude API conventions
- All Claude calls go through service objects in `app/services/ai/` (e.g. `Ai::BacktestScreenshotReader`).
  Controllers and models never call the SDK directly.
- One shared client: `Ai::Client.instance` (Anthropic::Client is thread-safe; create it once).
- Models: `claude-sonnet-5-5` for reasoning/analysis, `claude-haiku-5-5` for cheap extraction.
  Keep model names in `config/ai.yml`, never hard-coded in services.
- Use structured outputs / tool use for anything saved to the database. Never parse free text.
- Every Claude call is logged to an `AiCall` record: feature, model, input/output tokens,
  cost, latency, status. The admin shows cost per feature.
- Use prompt caching for long, repeated system prompts.
- Slow or bulk Claude work runs in Sidekiq jobs, never in the request cycle.
- API key comes from `ANTHROPIC_API_KEY` (Rails credentials in production). Never commit secrets.

## Coding standards
- Small, focused service objects with a single public `call` method.
- Every service and job has RSpec coverage. Claude calls are stubbed in tests (WebMock/VCR);
  tests must run without an API key.
- RuboCop (rubocop-rails-omakase) must pass.
- Commit in small steps with clear messages.

## Domain language
- Strategy: one trading system.
- StrategyVersion: one version of the Pine Script code + its parameter settings.
- Backtest: results of testing one StrategyVersion over a date range (from a screenshot or import).
- Trade: one live trade (entry, exit, side, size, P&L).

## Privacy
This repo is public. Never commit real strategy logic, real Pine Script, broker credentials,
PineConnector licenses or real account data. Use `db/seeds.rb` with realistic sample data.
