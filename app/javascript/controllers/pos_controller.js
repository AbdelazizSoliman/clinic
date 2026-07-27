import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["barcode", "search", "results"]

  connect() {
    this.barcodeTarget?.focus()
  }

  refocus() {
    requestAnimationFrame(() => this.barcodeTarget?.focus())
  }

  async search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(async () => {
      const query = this.searchTarget.value.trim()
      if (query.length < 2) {
        this.resultsTarget.innerHTML = ""
        return
      }
      const url = new URL(this.searchTarget.dataset.url, window.location.origin)
      url.searchParams.set("q", query)
      url.searchParams.set("sale_number", this.searchTarget.dataset.saleNumber)
      const response = await fetch(url, { headers: { Accept: "text/html" } })
      this.resultsTarget.innerHTML = response.ok ? await response.text() : "<p>تعذر البحث الآن.</p>"
    }, 180)
  }
}
