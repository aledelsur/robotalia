---
name: add-metric
description: Add a performance metric to Robotalia as a tested Ruby service and show it on the dashboard.
argument-hint: "<name> <definition>"
disable-model-invocation: true
---

Add this metric: $ARGUMENTS

Metrics are computed by tested Ruby, never by Claude. Claude only ever receives the results.

## 1. Settle the definition
Read `app/services/metrics/` and the "Notes from Day 2" in `docs/PLAN.md` first. Then write down the
formula, the unit, and what it is when there is nothing to measure. Decide how it treats:
- break-even trades (a win is net profit > 0, where net profit is profit + commission + swap)
- no trades, no losses, zero capital: return `nil`, not zero or infinity
- deposits and withdrawals (see `return_rate.rb`, `cash.rb` and the drawdown rule in `curve.rb`)
- the date, symbol and robot filters (`filter.rb`)
- how MT5 defines it, if it has it: say so in the interface when the two differ

If the name or definition above is missing or can be read in two ways, ask before writing code.

## 2. Put it where it belongs
- A ratio of the counts and sums already loaded: add a method to `Metrics::Tally` (`tally.rb`).
  `Summary` and `Breakdown` build on it.
- A column of the summary: extend `Summary` (`summary.rb`).
- Anything else: a new class in `app/services/metrics/` that takes a `Metrics::Filter` and has one
  public `call` method, plus a field in `Metrics::Dashboard::Result` (`dashboard.rb`).

Reuse the existing services. Aggregate in SQL where it is simple. Use `BigDecimal` for money.

## 3. Spec first
Add specs in `spec/services/metrics/` with the `deposit` and `closed` helpers from
`spec/support/metrics_account.rb`. Use a small account and work the expected value out by hand, with
the arithmetic in a comment. Cover the empty and undefined cases and at least one filter. See the
specs fail before writing the code.

## 4. Show it
Add it to `app/views/accounts/dashboard/`, formatted with the helpers in
`app/helpers/dashboard_helper.rb`. Show `nil` as the dashboard already shows undefined values. Add a
request spec expectation in `spec/requests/dashboard_spec.rb`.

## 5. Verify
Run `bundle exec rspec` and `bin/rubocop`. If the metric adds a query or walks every trade, run
`bin/rails perf:dashboard` and compare with the timings in `docs/PLAN.md`. Report the definition you
used and one hand-checked example.
