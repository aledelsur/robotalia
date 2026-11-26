# Robotalia: build plan

Tagline: "Robotalia – AI operations for trading robots"

Milestone: a deployed, demo-ready version within 4 days.
Goal: a polished Rails 8.1 app that showcases modern Rails and applied AI, built with Claude Code.
First product: an AI-powered performance dashboard for a trading account.

Done: setup (Rails 8.1, PostgreSQL 16 + Redis via docker compose, Sidekiq, RSpec/WebMock/VCR,
RuboCop/Brakeman, CI workflow, Dockerfiles), Day 1 (sign-in, models, MT5 .xlsx import,
synthetic demo account) and Day 2 (deploy, metrics, dashboard).

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

Notes from Day 1:
- Only the .xlsx report is supported. Add HTML only if needed.
- Trades come from the report's Positions section: deals name their order, not their position.
  The entry deal's comment names the robot. The report has no magic number.
- Merging a position that is listed once per partial close is covered by a synthetic test only;
  no real report with a partial close has been checked.
- Times are broker server time, stored as written.

## Day 2: Deploy, then the performance dashboard
Done:
1. Server setup (`script/server/setup.sh`: updates, SSH keys only, Docker, firewall, swap) and a
   bare Kamal 2 deploy (web, Sidekiq, PostgreSQL, Redis, SSL). https://robotalia.app is live with
   the synthetic demo account, so each later step only needs `bin/kamal deploy`. Server address,
   hostname and database password come from `.env.deploy` (see `.env.deploy.example`). Report
   imports are switched off in production (`IMPORTS_ENABLED`).
2. Group robots by model: drop the Long/Short token (any case, any position) from the comment and
   group by what is left, so `M3_EURUSD_Long` and `M3_EURUSD_Short` are one robot,
   "Model 3 · EURUSD". The long/short breakdown comes from the trade side. The demo keeps real,
   common symbols (EURUSD, GBPUSD, XAUUSD, US30, NAS100) with invented trades and robot names.
3. `Metrics` service objects (pure Ruby, fully tested): net profit, return %, win rate, profit
   factor, expectancy, average win/loss, max drawdown (amount and %), longest losing streak,
   equity and balance curves, monthly returns. A win is net profit > 0 (profit + commission +
   swap); break-even trades are counted separately. MT5 counts them as winners, so the dashboard
   also shows the MT5-style win rate and explains the difference.
4. Dashboard page: KPI cards, equity curve with drawdown, monthly returns heatmap,
   breakdown by symbol and by robot, trades table with server-side sorting, filters and
   pagination (Turbo Frames).
5. Date-range, symbol and robot filters that update the whole page without a full reload.
6. Fast queries, measured with `bin/rails perf:dashboard` (a throwaway account of 10.6K trades):
   the unfiltered dashboard takes about 220 ms on the development laptop and a filtered one about
   35 ms. About half of the unfiltered time is Ruby building the equity curve. No new indexes or
   cached snapshots are needed. Redeploy.

Notes from Day 2:
- Returns, for the whole range and for each month: net profit / (balance when the period starts +
  deposits during it). With a symbol or robot filter the capital is still the whole account's.
- Drawdown is measured from the balance peak, which deposits and withdrawals move by their own
  amount. Max drawdown in money and in percent are each the largest, so they can be different dips.
- Charts show one point per day (the day's close and its deepest drawdown).

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
