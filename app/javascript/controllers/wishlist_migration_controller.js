import { Controller } from "@hotwired/stimulus"

const WISHLIST_KEY = "pharmacy_store_wishlist_v1"
const MARKER_KEY = "pharmacy_store_wishlist_server_migrated_v1"

export default class extends Controller {
  connect() {
    if (localStorage.getItem(MARKER_KEY) || !localStorage.getItem(WISHLIST_KEY) || this.importing) return
    this.importing = true
    this.import()
  }

  async import() {
    let stored
    try { stored = JSON.parse(localStorage.getItem(WISHLIST_KEY)) } catch (_error) { return }
    if (stored?.version !== 1 || !Array.isArray(stored.productIds)) return

    try {
      const response = await fetch("/wishlist/import_browser", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content, "Accept": "application/json" },
        body: JSON.stringify({ product_ids: stored.productIds })
      })
      if (!response.ok) return
      localStorage.removeItem(WISHLIST_KEY)
      localStorage.setItem(MARKER_KEY, "true")
      window.location.reload()
    } catch (_error) {
      this.importing = false
    }
  }
}
