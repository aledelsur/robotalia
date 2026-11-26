import { Controller } from "@hotwired/stimulus"

// Fallback for a broadcast sent before the page had subscribed to the stream, which can
// happen when a job finishes very quickly. Reloads the page while the element is present.
export default class extends Controller {
  static values = { interval: { type: Number, default: 3000 } }

  connect() {
    this.timer = setTimeout(() => Turbo.visit(window.location.href, { action: "replace" }), this.intervalValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
