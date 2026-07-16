import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop", "trigger", "close"]
  connect() { this.keydown = this.keydown.bind(this) }
  disconnect() { document.removeEventListener("keydown", this.keydown); document.body.classList.remove("overflow-hidden") }
  open() { this.panelTarget.classList.remove("translate-x-full"); this.panelTarget.setAttribute("aria-hidden", "false"); this.backdropTarget.classList.remove("hidden"); this.triggerTarget.setAttribute("aria-expanded", "true"); document.body.classList.add("overflow-hidden"); document.addEventListener("keydown", this.keydown); requestAnimationFrame(() => this.closeTarget.focus()) }
  close() { this.panelTarget.classList.add("translate-x-full"); this.panelTarget.setAttribute("aria-hidden", "true"); this.backdropTarget.classList.add("hidden"); this.triggerTarget.setAttribute("aria-expanded", "false"); document.body.classList.remove("overflow-hidden"); document.removeEventListener("keydown", this.keydown); this.triggerTarget.focus() }
  backdrop(event) { if (event.target === this.backdropTarget) this.close() }
  keydown(event) {
    if (event.key === "Escape") return this.close()
    if (event.key !== "Tab") return
    const focusable = this.panelTarget.querySelectorAll("button, [href], input, [tabindex]:not([tabindex='-1'])")
    const first = focusable[0], last = focusable[focusable.length - 1]
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
  }
}
