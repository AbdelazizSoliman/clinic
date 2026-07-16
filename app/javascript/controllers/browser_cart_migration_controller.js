import { Controller } from "@hotwired/stimulus"

const CART_KEY = "pharmacy_store_cart_v1"
const MARKER_KEY = "pharmacy_store_cart_server_migrated_v1"

export default class extends Controller {
  connect() {
    if (localStorage.getItem(MARKER_KEY) || !localStorage.getItem(CART_KEY)) return

    this.import()
  }

  async import() {
    let stored
    try { stored = JSON.parse(localStorage.getItem(CART_KEY)) } catch (_error) { localStorage.removeItem(CART_KEY); return }
    if (stored?.version !== 1 || !Array.isArray(stored.items)) { localStorage.removeItem(CART_KEY); return }

    try {
      const response = await fetch("/cart/import_browser", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content, "Accept": "application/json" },
        body: JSON.stringify({ items: stored.items })
      })
      if (!response.ok) return
      localStorage.removeItem(CART_KEY)
      localStorage.setItem(MARKER_KEY, "true")
      window.location.reload()
    } catch (_error) {
      // Keep the original key so a later Turbo visit can retry safely.
    }
  }
}
