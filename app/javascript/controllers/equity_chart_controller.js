import { Controller } from "@hotwired/stimulus"
import "chart.js"

const EQUITY = "#257de0"
const BALANCE = "#f47230"
const DRAWDOWN = "#dc3c3d"
const GRID = "#e7e7e7"
const TEXT = "#666666"

const shortDate = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", timeZone: "UTC" })
const longDate = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" })

// A vertical hairline at the hovered day.
const crosshair = {
  id: "crosshair",
  afterDatasetsDraw(chart) {
    const active = chart.tooltip?.getActiveElements()
    if (!active?.length) return

    const { ctx, chartArea } = chart
    const x = active[0].element.x
    ctx.save()
    ctx.strokeStyle = "#c2c2c2"
    ctx.beginPath()
    ctx.moveTo(x, chartArea.top)
    ctx.lineTo(x, chartArea.bottom)
    ctx.stroke()
    ctx.restore()
  }
}

// Draws the equity and drawdown charts from points of [date, balance, equity, drawdown %].
// Two charts rather than two y-axes: money and percentages don't share a scale.
export default class extends Controller {
  static targets = ["equity", "drawdown"]
  static values = { points: Array, currency: String }

  connect() {
    const dates = this.pointsValue.map(([date]) => date)
    const column = (index) => this.pointsValue.map((point) => point[index])
    const money = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    const compact = new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 1 })

    this.charts = [
      this.draw(this.equityTarget, dates, {
        datasets: [
          this.line("Equity", column(2), EQUITY),
          this.line("Balance", column(1), BALANCE)
        ],
        tick: (value) => compact.format(value),
        label: (item) => `${this.currencyValue} ${money.format(item.parsed.y)}  ${item.dataset.label}`
      }),
      this.draw(this.drawdownTarget, dates, {
        datasets: [{ ...this.line("Drawdown", column(3), DRAWDOWN), fill: "origin", backgroundColor: `${DRAWDOWN}1a` }],
        tick: (value) => `${value}%`,
        label: (item) => `${item.parsed.y.toFixed(2)}%  Drawdown`,
        // Deeper drawdowns hang further down.
        y: { reverse: true, beginAtZero: true }
      })
    ]
  }

  disconnect() {
    this.charts?.forEach((chart) => chart.destroy())
  }

  line(label, data, color) {
    return {
      label, data, borderColor: color, backgroundColor: color, borderWidth: 2, borderJoinStyle: "round",
      pointRadius: data.length === 1 ? 4 : 0, pointHoverRadius: 4
    }
  }

  draw(canvas, dates, { datasets, tick, label, y = {} }) {
    return new window.Chart(canvas, {
      type: "line",
      data: { labels: dates, datasets },
      plugins: [crosshair],
      options: {
        animation: false,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: { title: ([item]) => longDate.format(new Date(item.label)), label } }
        },
        scales: {
          x: {
            grid: { display: false },
            border: { color: "#c2c2c2" },
            ticks: {
              color: TEXT, maxRotation: 0, autoSkipPadding: 24,
              callback: (_, index) => shortDate.format(new Date(dates[index]))
            }
          },
          y: {
            ...y,
            grid: { color: GRID },
            border: { display: false },
            ticks: { color: TEXT, callback: tick, maxTicksLimit: 6 },
            // The same width on both charts keeps their dates lined up.
            afterFit: (scale) => { scale.width = 52 }
          }
        }
      }
    })
  }
}
