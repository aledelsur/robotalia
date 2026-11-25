# Robotalia: build plan

Tagline: "Robotalia – AI operations for trading robots"

Goal: a production-quality Rails 8 + Claude app that proves modern Rails and applied-AI skills,
built with Claude Code. Work one phase at a time; each phase ends with green tests and a commit.

## Phase 1: Foundation and backtest screenshot reader (MVP)
1. `rails new . --name=robotalia --database=postgresql --css=tailwind --skip-solid` (Ruby 3.4.13, Rails 8.1), keeping CLAUDE.md and docs/.
2. Docker: `Dockerfile` (Rails 8 default) + `docker-compose.yml` with web, postgres, redis, sidekiq.
   `bin/dev` and `docker compose up` must both work.
3. Sidekiq + Redis configured as the Active Job adapter; Sidekiq web UI mounted behind admin auth.
4. Authentication: Rails 8 built-in authentication generator (single owner account).
5. Models and migrations: Strategy, StrategyVersion, Backtest, Trade, AiCall.
6. Avo admin for all models, plus an "AI usage" dashboard (tokens and cost per feature from AiCall).
7. `Ai::Client` + `config/ai.yml` + AiCall logging.
8. Feature: **Backtest screenshot reader**
   - Upload one or many TradingView Strategy Tester screenshots (Active Storage).
   - `ExtractBacktestJob` sends each image to Claude (vision) and gets structured output:
     net profit (% and amount), max drawdown, win rate, profit factor, total trades, date range.
   - Results saved to Backtest; low-confidence fields flagged for review.
   - Bulk mode uses the Message Batches API for large uploads.
9. Strategy page: versions + backtests table, sortable; best version highlighted.
10. Seeds with realistic sample data; RSpec for models, services and jobs.

## Phase 2: Live trades and drawdown watchdog
1. `POST /webhooks/trades`: authenticated JSON webhook (token per strategy) for trade open/close events.
   Source: a second TradingView alert, or CSV import of MetaTrader 5 trade history.
2. Trade journal UI with live updates (Turbo Streams).
3. `DrawdownWatchdogJob` (sidekiq-cron, every 5 min): equity curve + drawdown per strategy.
4. When a drawdown alert triggers: Telegram/email alert + `Ai::LosingStreakAnalyst` writes an analysis
   of the recent losing trades.
5. `Ai::VersionDiffExplainer`: compare two StrategyVersions (code + params) and explain the changes
   and the likely effect on results.

## Phase 3: AI agent
1. "Ask Robotalia" chat: Claude with tool use, streamed to the page with Turbo Streams.
   Tools are safe Ruby methods, e.g. `list_strategies`, `backtests_for(strategy, filters)`,
   `trades_between(dates)`, `equity_curve(strategy)`, `compare_versions(a, b)`. Read-only.
2. pgvector + embeddings (Voyage AI) over strategy notes and version explanations for semantic search.
3. `WeeklyReportJob`: Claude writes a weekly performance report, emailed every Monday.
4. Evals: `spec/evals/` with known screenshots and questions; checks extraction accuracy
   and answer quality. Run with `bin/evals`.

## Phase 4: Ship it
1. Kamal 2 deploy to a VPS (Hetzner or similar): web, sidekiq, postgres, redis accessories, SSL.
2. GitHub Actions: RSpec, RuboCop, Brakeman on every PR; deploy on main.
3. README: what it does, architecture diagram, AI features, how to run locally, screenshots, demo GIF.
4. Stretch: MCP server exposing Robotalia tools to Claude Desktop / Claude Code.

## Architecture (target)
Browser (Hotwire) -> Rails 8 (Puma) -> PostgreSQL (+pgvector)
                                  -> Redis -> Sidekiq jobs -> Claude API (vision, tools, batches)
TradingView / MT5 -> webhook / CSV import -> Rails
Sidekiq-cron -> watchdog / weekly report -> Telegram / email
