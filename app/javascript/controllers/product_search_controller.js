import { Controller } from "@hotwired/stimulus"

// Debounced, keyboard-navigable product search panel.
// Renders server-side HTML only: the endpoint owns authorization, filtering and escaping.
export default class extends Controller {
  static targets = ["input", "panel", "status"]
  static values = { url: String, minLength: { type: Number, default: 2 }, delay: { type: Number, default: 200 } }

  connect() {
    this.activeIndex = -1
    this.onDocumentClick = (event) => { if (!this.element.contains(event.target)) this.close() }
    document.addEventListener("click", this.onDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    clearTimeout(this.timer)
    this.controller?.abort()
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.fetchResults(), this.delayValue)
  }

  async fetchResults() {
    const query = this.inputTarget.value.trim()
    if (query.length < this.minLengthValue) return this.close()

    this.controller?.abort()
    this.controller = new AbortController()
    this.setBusy(true)
    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)
      for (const [key, value] of Object.entries(this.element.dataset)) {
        if (key.startsWith("searchParam")) {
          url.searchParams.set(key.replace("searchParam", "").toLowerCase(), value)
        }
      }
      const response = await fetch(url, { headers: { Accept: "text/html" }, signal: this.controller.signal })
      if (!response.ok) return this.close()
      this.panelTarget.innerHTML = await response.text()
      this.open()
    } catch (error) {
      if (error.name !== "AbortError") this.close()
    } finally {
      this.setBusy(false)
    }
  }

  navigate(event) {
    const options = this.options
    if (event.key === "Escape") return this.close()
    if (!options.length) return
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.activeIndex = (this.activeIndex + step + options.length) % options.length
      this.highlight()
    } else if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      options[this.activeIndex].querySelector("a")?.click()
    }
  }

  get options() { return this.hasPanelTarget ? Array.from(this.panelTarget.querySelectorAll("[role='option']")) : [] }

  highlight() {
    this.options.forEach((option, index) => {
      const active = index === this.activeIndex
      option.dataset.active = active
      option.setAttribute("aria-selected", active)
      if (active) { option.scrollIntoView({ block: "nearest" }); this.inputTarget.setAttribute("aria-activedescendant", option.id) }
    })
  }

  open() {
    this.activeIndex = -1
    this.panelTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.activeIndex = -1
    if (this.hasPanelTarget) { this.panelTarget.classList.add("hidden"); this.panelTarget.innerHTML = "" }
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  setBusy(busy) {
    if (this.hasStatusTarget) this.statusTarget.classList.toggle("hidden", !busy)
    this.inputTarget.setAttribute("aria-busy", busy)
  }
}
