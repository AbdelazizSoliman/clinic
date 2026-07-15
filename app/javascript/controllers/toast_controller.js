import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]
  connect() { this.show = this.show.bind(this); window.addEventListener("pharmacy:toast", this.show) }
  disconnect() { window.removeEventListener("pharmacy:toast", this.show) }
  show(event) {
    const existing = [...this.listTarget.children].find(item => item.dataset.message === event.detail.message)
    if (existing) return
    const colors = { success: "border-pharmacy-500", information: "border-sky-500", warning: "border-amber-500", error: "border-rose-500" }
    const toast = document.createElement("div")
    toast.dataset.message = event.detail.message
    toast.className = `pointer-events-auto flex items-start gap-3 rounded-xl border-r-4 bg-white p-4 shadow-xl ${colors[event.detail.type] || colors.information}`
    const message = document.createElement("p"); message.className = "flex-1 text-sm font-bold"; message.textContent = event.detail.message
    const close = document.createElement("button"); close.type = "button"; close.className = "text-slate-500"; close.setAttribute("aria-label", "إغلاق الإشعار"); close.textContent = "✕"; close.onclick = () => toast.remove()
    toast.append(message, close); this.listTarget.append(toast)
    const timer = setTimeout(() => toast.remove(), 5000)
    toast.addEventListener("mouseenter", () => clearTimeout(timer), { once: true })
    toast.addEventListener("focusin", () => clearTimeout(timer), { once: true })
  }
}
