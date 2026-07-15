import { Controller } from "@hotwired/stimulus"
import { validCartItems, cartQuantity, subtotalCents, formatMoney, cartItemMarkup, setQuantity, clearCart } from "lib/shopping_store"

export default class extends Controller {
  static targets = ["panel", "backdrop", "trigger", "close", "items", "empty", "content", "count", "subtotal", "prescription"]
  connect() {
    this.refresh = this.refresh.bind(this); this.keydown = this.keydown.bind(this)
    window.addEventListener("pharmacy:cart-changed", this.refresh)
    this.refresh()
  }
  disconnect() { window.removeEventListener("pharmacy:cart-changed", this.refresh); document.removeEventListener("keydown", this.keydown); document.body.classList.remove("overflow-hidden") }
  open() { this.panelTarget.classList.remove("translate-x-full"); this.backdropTarget.classList.remove("hidden"); this.triggerTarget.setAttribute("aria-expanded", "true"); document.body.classList.add("overflow-hidden"); document.addEventListener("keydown", this.keydown); requestAnimationFrame(() => this.closeTarget.focus()) }
  close() { this.panelTarget.classList.add("translate-x-full"); this.backdropTarget.classList.add("hidden"); this.triggerTarget.setAttribute("aria-expanded", "false"); document.body.classList.remove("overflow-hidden"); document.removeEventListener("keydown", this.keydown); this.triggerTarget.focus() }
  backdrop(event) { if (event.target === this.backdropTarget) this.close() }
  keydown(event) {
    if (event.key === "Escape") return this.close()
    if (event.key !== "Tab") return
    const focusable = this.panelTarget.querySelectorAll("button, [href], input, [tabindex]:not([tabindex='-1'])")
    const first = focusable[0], last = focusable[focusable.length - 1]
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
  }
  itemAction(event) {
    const action = event.target.dataset.cartAction
    if (!action) return
    const id = Number(event.target.closest("[data-product-id]").dataset.productId)
    const item = validCartItems().find(entry => entry.productId === id)
    if (action === "increase") setQuantity(id, item.quantity + 1)
    if (action === "decrease" && item.quantity > 1) setQuantity(id, item.quantity - 1)
    if (action === "remove") setQuantity(id, 0)
    if (action === "quantity" && event.type === "change") setQuantity(id, Math.max(1, Number(event.target.value) || 1))
  }
  clear() { if (window.confirm("هل تريد إفراغ سلة التسوق بالكامل؟")) clearCart() }
  refresh() {
    const items = validCartItems()
    this.itemsTarget.innerHTML = items.map(item => cartItemMarkup(item, true)).join("")
    this.emptyTarget.classList.toggle("hidden", items.length > 0); this.contentTarget.classList.toggle("hidden", items.length === 0)
    this.countTarget.textContent = cartQuantity(); this.subtotalTarget.textContent = formatMoney(subtotalCents())
    this.prescriptionTarget.classList.toggle("hidden", !items.some(item => item.product.prescription))
  }
}
