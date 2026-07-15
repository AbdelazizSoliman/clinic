import { Controller } from "@hotwired/stimulus"
import { validCartItems, cartQuantity, subtotalCents, formatMoney, cartItemMarkup, setQuantity, clearCart, cartNeedsAttention } from "lib/shopping_store"

export default class extends Controller {
  static targets = ["items", "empty", "content", "count", "subtotal", "discount", "total", "attention", "prescription"]
  connect() {
    this.discountPercent = 0; this.refresh = this.refresh.bind(this); this.promo = this.promo.bind(this)
    window.addEventListener("pharmacy:cart-changed", this.refresh); window.addEventListener("pharmacy:promo-changed", this.promo); this.refresh()
  }
  disconnect() { window.removeEventListener("pharmacy:cart-changed", this.refresh); window.removeEventListener("pharmacy:promo-changed", this.promo) }
  itemAction(event) {
    const action = event.target.dataset.cartAction; if (!action) return
    const id = Number(event.target.closest("[data-product-id]").dataset.productId)
    const item = validCartItems().find(entry => entry.productId === id); if (!item) return
    if (action === "increase") setQuantity(id, item.quantity + 1)
    if (action === "decrease" && item.quantity > 1) setQuantity(id, item.quantity - 1)
    if (action === "remove") setQuantity(id, 0)
    if (action === "quantity" && event.type === "change") setQuantity(id, Math.max(1, Number(event.target.value) || 1))
  }
  clear() { if (window.confirm("هل تريد إفراغ سلة التسوق بالكامل؟")) clearCart() }
  promo(event) { this.discountPercent = event.detail.percent; this.refreshTotals() }
  refresh() {
    const items = validCartItems(); const empty = items.length === 0
    this.itemsTarget.innerHTML = items.map(item => cartItemMarkup(item)).join("")
    this.emptyTarget.classList.toggle("hidden", !empty); this.contentTarget.classList.toggle("hidden", empty)
    this.countTarget.textContent = cartQuantity()
    this.attentionTarget.classList.toggle("hidden", !cartNeedsAttention())
    this.prescriptionTarget.classList.toggle("hidden", !items.some(item => item.product.prescription))
    this.refreshTotals()
  }
  refreshTotals() {
    const subtotal = subtotalCents(); const discount = Math.round(subtotal * this.discountPercent / 100)
    this.subtotalTarget.textContent = formatMoney(subtotal); this.discountTarget.textContent = discount ? `− ${formatMoney(discount)}` : "—"; this.totalTarget.textContent = formatMoney(subtotal - discount)
  }
}
