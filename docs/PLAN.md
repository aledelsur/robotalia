# Robotalia: build plan

Tagline: "Robotalia – AI operations for trading robots"

Milestone: a deployed, demo-ready version within 4 days.
Goal: a polished Rails 8.1 app that showcases modern Rails and applied AI, built with Claude Code.
First product: an AI-powered performance dashboard for a trading account.

Already done (setup): Rails 8.1 app, PostgreSQL 16 + Redis via docker compose, Sidekiq,
RSpec/WebMock/VCR, RuboCop/Brakeman, CI workflow, Dockerfiles. Single-owner sign-in is
half-built in `git stash` ("WIP step 4").

Each step ends with green tests and a commit. Prefer a smaller, polished, working scope over
unfinished features. If a day's work runs late, cut scope, not quality.

## Data source
- Day 1-4: import trade history from a MetaTrader 5 account report (exported by the owner from
  the MT5 terminal, History tab -> Report). Support the formats MT5 actually produces (check the
  real file: HTML and/or XLSX). Imports are idempotent (dedupe by deal/position ticket).
- A synthetic demo account (seeds) so the public demo never shows real data.
- Live, read-only account sync behind an `AccountSync` adapter interface (MT5 report import is one
  adapter). A sidekiq-cron job syncs every few minutes, upserting by ticket. Credentials and
  sessions are stored with Active Record Encryption, never in code or logs. Verify the real API
  responses before writing the parser.
  Priority: after the dashboard works (Day 2-3), cut if time is short.

## Day 1: Foundation and import
1. Finish single-owner authentication from the stash; Sidekiq web UI behind sign-in.
2. Models: Account (broker, server, currency, initial balance), Deal and/or Trade (ticket,
   symbol, side, volume, open/close time and price, SL/TP, commission, swap, profit, comment/magic
   number), BalanceOperation (deposits/withdrawals), AccountImport, AiCall. Avo resources.
3. MT5 report import: Active Storage upload + Sidekiq job, parsing, validation, idempotent upsert,
   import summary (new, updated, skipped, errors) shown live with Turbo Streams.
4. Idempotent seeds: a realistic synthetic demo account (several symbols and robots, ~6 months).

## Day 2: Performance dashboard
1. `Metrics` service objects (pure Ruby, fully tested): net profit, return %, win rate, profit
   factor, expectancy, average win/loss, max drawdown (amount and %), longest losing streak,
   equity and balance curves, monthly returns.
2. Dashboard page: KPI cards, equity curve with drawdown, monthly returns heatmap,
   breakdown by symbol and by robot (comment/magic number), trades table with server-side
   sorting, filters and pagination (Turbo Frames).
3. Date-range and symbol filters that update the whole page without a full reload.
4. Fast queries: proper indexes, cached metric snapshots per account, measured with a seed of
   ~10K trades.

## Day 3: Claude features
1. `Ai::PerformanceAnalyst`: receives computed metrics (never raw guesses) and returns structured
   output: summary, strengths, risks, unusual patterns, suggestions. Runs in a Sidekiq job,
   result streamed to the page. Clearly labelled as analysis, not financial advice.
2. "Ask Robotalia" chat: Claude with read-only tools over the account (e.g. `metrics_for`,
   `trades_between`, `breakdown_by_symbol`, `drawdown_periods`), streamed with Turbo Streams.
3. AiCall logging and `/ai_usage` page (tokens, cost, latency, errors per feature).
4. Evals in `spec/evals/` for the analyst on fixed metric sets.

## Day 4: Ship
1. Kamal 2 deploy to a VPS with SSL, Sidekiq and Redis; demo login with the synthetic account.
2. GitHub repo (public): README with problem, screenshots/GIF, architecture diagram, how Claude is
   used, how to run locally, test/CI badges. CI green on GitHub Actions.
3. Final check: fresh `docker compose up --build`, seeds, sign in, import a sample report, dashboard,
   AI summary, chat.

## Later
- Live account sync through an `AccountSync` adapter (MT5 investor access or broker API).
- Settings optimizer for Pine Script strategies on exported TradingView data, with a broker
  emulator matching TradingView's Strategy Tester and walk-forward validation.
- Drawdown watchdog with alerts; weekly AI report email; MCP server.

## Architecture (target)
MT5 report (manual export) -> Upload -> Rails 8.1 -> Sidekiq import job -> PostgreSQL
Dashboard (Hotwire, Turbo Streams/Frames) <- Metrics services <- cached snapshots
Ai::PerformanceAnalyst / chat tools (Claude, via Sidekiq) -> streamed results; AiCall logging
Deploy: Kamal 2 -> VPS (web, sidekiq, postgres, redis)
