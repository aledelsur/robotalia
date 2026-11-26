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

## Production and the public demo
- Production holds only the synthetic demo account. Real reports and trades stay on the owner's machine.
- Visitors sign in as a demo user, which is read-only: imports are disabled.
- Claude calls are capped per day, because demo visitors trigger paid requests.

## Data source
- Day 1-4: import trade history from a MetaTrader 5 account report (exported by the owner from
  the MT5 terminal, History tab -> Report). Support the formats MT5 actually produces (check the
  real file: HTML and/or XLSX). Imports are idempotent (dedupe by deal/position ticket).
- A synthetic demo account (seeds) so the public demo never shows real data.

## Day 1: Foundation and import
1. Finish single-owner authentication from the stash; Sidekiq web UI behind sign-in. Users get a
   `demo` flag.
2. Models: Account (broker, server, currency, initial balance), Deal and Trade (ticket,
   symbol, side, volume, open/close time and price, SL/TP, commission, swap, profit, comment/magic
   number), BalanceOperation (deposits/withdrawals), Robot, AccountImport. A Deal is the raw row from
   the report; a Trade is the closed position derived from its deals.
3. MT5 report import: Active Storage upload + Sidekiq job, parsing, validation, idempotent upsert,
   import status and summary (new, updated, skipped, errors) shown live with Turbo Streams.
4. Idempotent seeds: a realistic synthetic demo account (several symbols and robots, ~6 months).

## Day 2: Performance dashboard
1. `Metrics` service objects (pure Ruby, fully tested): net profit, return %, win rate, profit
   factor, expectancy, average win/loss, max drawdown (amount and %), longest losing streak,
   equity and balance curves, monthly returns.
2. Dashboard page: KPI cards, equity curve with drawdown, monthly returns heatmap,
   breakdown by symbol and by robot (comment/magic number), trades table with server-side
   sorting, filters and pagination (Turbo Frames).
3. Date-range and symbol filters that update the whole page without a full reload.
4. Fast queries: proper indexes, measured with a seed of ~10K trades. Add cached metric snapshots
   only if the measurement shows a slow page.
5. End of day: bare Kamal 2 deploy (web, Sidekiq, PostgreSQL, Redis, SSL) with `/up` green.

## Day 3: Claude features
1. AiCall model and logging, the daily Claude-call cap, and the `/ai_usage` page (tokens, cost,
   latency, errors per feature).
2. `Ai::PerformanceAnalyst`: receives computed metrics (never raw guesses) and returns structured
   output: summary, strengths, risks, unusual patterns, suggestions. Runs in a Sidekiq job; the
   finished result is broadcast to the page. Clearly labelled as analysis, not financial advice.
3. "Ask Robotalia" chat: Claude with three read-only tools over the account (`metrics_for`,
   `trades_between`, `breakdown_by_symbol`). Each answer is broadcast when complete. Token
   streaming only if time is left.
4. Evals in `spec/evals/`: the analyst on 2-3 fixed metric sets, recorded with VCR, asserting the
   structure and that every number it quotes was in its input.

## Day 4: Ship
1. Redeploy to the VPS. Demo login with the synthetic account: read-only, imports disabled.
2. GitHub repo (public): README with problem, screenshots/GIF, architecture diagram, how Claude is
   used, how to run locally, test/CI badges. CI green on GitHub Actions.
3. Final check: fresh `docker compose up --build`, seeds, sign in, import a sample report, dashboard,
   AI summary, chat. The local check uses the synthetic sample report.
4. Optional, if time is left: Avo resources (free tier).

## Later
- Live, read-only account sync behind an `AccountSync` adapter interface (MT5 report import is the
  first adapter). A sidekiq-cron job upserts by ticket. Credentials and sessions use Active Record
  Encryption, never code or logs. Verify the real API responses before writing a parser.
- Settings optimizer for Pine Script strategies on exported TradingView data, with a broker
  emulator matching TradingView's Strategy Tester and walk-forward validation.
- Drawdown watchdog with alerts; weekly AI report email; MCP server.

## Architecture (target)
MT5 report (manual export) -> Upload -> Rails 8.1 -> Sidekiq import job -> PostgreSQL
Dashboard (Hotwire, Turbo Streams/Frames) <- Metrics services <- PostgreSQL
Ai::PerformanceAnalyst / chat tools (Claude, via Sidekiq) -> broadcast results; AiCall logging
Deploy: Kamal 2 -> VPS (web, sidekiq, postgres, redis)
