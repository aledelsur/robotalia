namespace :perf do
  desc "Time the dashboard on a throwaway account of about 10K trades (rolled back afterwards)"
  task dashboard: :environment do
    abort "Run this on a development machine." if Rails.env.production?

    # Quiet, so the log doesn't dominate the timings.
    ActiveRecord::Base.logger = nil
    ActionView::Base.logger = nil

    # Best of three runs, in milliseconds, with the number of queries of one run.
    measure = lambda do |label, &block|
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      times = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        3.times.map do
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          ActiveRecord::Base.uncached(&block)
          (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
        end
      end
      puts format("%-34s %8.1f ms %5d queries", label, times.min, queries / 3)
    end

    ActiveRecord::Base.transaction do
      data = Demo::AccountGenerator.new(period: Date.new(2018, 1, 1)..Date.new(2026, 10, 30)).report
      account = Account.create!(name: "Performance run", login: "perf-run", server: "Perf", currency: "USD")
      Mt5Report::AccountWriter.new(account, data).call
      ActiveRecord::Base.connection.execute("ANALYZE trades, deals, balance_operations, robots")
      puts "#{account.trades.count} trades\n\n"

      account.reload
      robot = account.robots.order(:name).first
      {
        "no filter" => {},
        "one year, one robot" => { from: Date.new(2025, 1, 1), to: Date.new(2025, 12, 31), robot_id: robot.id }
      }.each do |name, options|
        filter = Metrics::Filter.new(account:, **options)
        puts "#{name}:"
        measure.call("  summary") { Metrics::Summary.new(filter).call }
        measure.call("  curve") { Metrics::Curve.new(filter).call }
        measure.call("  monthly returns") { Metrics::MonthlyReturns.new(filter).call }
        measure.call("  breakdowns") { %i[symbol robot].each { Metrics::Breakdown.new(filter, by: _1).call } }

        html = nil
        measure.call("  dashboard (queries + HTML)") do
          html = ApplicationController.render(
            template: "accounts/show", layout: false,
            assigns: { account:, filter:, dashboard: Metrics::Dashboard.new(filter).call, imports: [] }
          )
        end
        puts format("%-34s %8.1f KB", "  dashboard HTML", html.bytesize / 1024.0)

        %w[closed_at net_profit].each do |column|
          measure.call("  trades page 5, by #{column}") do
            filter.trades.includes(:robot).order(column => :desc, position_id: :desc).offset(100).limit(25).to_a
            filter.trades.count
          end
        end
        puts
      end

      raise ActiveRecord::Rollback
    end
  end
end
