// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// A frame visit that advances the URL snapshots the page while the frame is still marked
// busy, so Back restores it faded. Once a page has loaded, the dashboard frame has no
// request of its own in flight, so its markers are stale.
document.addEventListener("turbo:load", () => {
  const frame = document.getElementById("dashboard")
  frame?.removeAttribute("busy")
  frame?.removeAttribute("aria-busy")
})
