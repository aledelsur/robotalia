module DashboardHelper
  DASH = "–"
  # Diverging blue/red, stronger further from zero. Whole class names, so Tailwind sees them.
  HEAT = {
    gain: [ "bg-[#cce3fd] text-gray-900", "bg-[#84b9f3] text-gray-900", "bg-[#1b64be] text-white" ],
    loss: [ "bg-[#fbd9d9] text-gray-900", "bg-[#f39c9c] text-gray-900", "bg-[#b82f30] text-white" ]
  }.freeze
  HEAT_STEPS = [ 0.02, 0.05 ].freeze

  def money(amount, currency)
    amount ? number_to_currency(amount, unit: "#{currency} ") : DASH
  end

  def percent(rate, precision: 1)
    rate ? number_to_percentage(rate * 100, precision:) : DASH
  end

  def ratio(value)
    value ? number_with_precision(value, precision: 2) : DASH
  end

  def profit_class(amount)
    return "text-gray-900" if amount.nil? || amount.zero?

    amount.positive? ? "text-[#1b64be]" : "text-[#b82f30]"
  end

  # The headline figure only: tables and breakdowns keep the blue/red of profit_class.
  def net_profit_class(amount)
    return "text-gray-500" if amount.nil? || amount.zero?

    amount.positive? ? "text-green-700" : "text-red-700"
  end

  def heat_class(rate)
    return "bg-gray-100 text-gray-900" if rate.nil? || rate.zero?

    step = HEAT_STEPS.index { rate.abs < _1 } || HEAT_STEPS.size
    HEAT.fetch(rate.positive? ? :gain : :loss)[step]
  end

  # Ranges ending on the account's last trading day, not today: a report is only as
  # recent as its export.
  def range_presets(last_day)
    {
      "All time" => nil,
      "Last 30 days" => last_day - 29,
      "Last 90 days" => last_day - 89,
      "Year to date" => last_day.beginning_of_year
    }.map do |label, from|
      [ label, { from: from&.iso8601, to: from && last_day.iso8601 } ]
    end
  end

  def curve_chart_data(curve)
    curve.daily.map do |point|
      [ point.time.to_date.iso8601, point.balance.to_f, point.equity.to_f, ((point.drawdown_rate || 0) * 100).round(2) ]
    end
  end

  # The chart's table view: where each month closed, and its deepest drawdown.
  def curve_months(curve)
    curve.points.group_by { _1.time.to_date.beginning_of_month }.map do |month, points|
      [ month, points.last, points.filter_map(&:drawdown_rate).max ]
    end
  end

  def sort_header(label, column, numeric: false)
    active = @sort == column
    direction = active && @direction == "desc" ? "asc" : "desc"
    arrow = @direction == "asc" ? "▲" : "▼"
    url = account_trades_path(@account, **@filter.to_params, sort: column, direction:)

    tag.th(scope: "col", class: [ "px-3 py-2 font-medium", numeric ? "text-right" : "text-left" ],
           aria: { sort: (@direction == "asc" ? "ascending" : "descending" if active) }) do
      link_to url, class: [ "hover:text-gray-900", ("text-gray-900" if active) ] do
        safe_join([ label, (tag.span(" #{arrow}", aria: { hidden: true }) if active) ])
      end
    end
  end
end
