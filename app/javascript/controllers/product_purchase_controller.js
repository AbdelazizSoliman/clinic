import { Controller } from "@hotwired/stimulus"
import { addToCart, quantityFor, setQuantity, toast, MAX_QUANTITY } from "lib/shopping_store"

export default class extends Controller {
  static values = { productId: Number, available: Boolean, max: { type: Number, default: MAX_QUANTITY } }
  static targets = ["add", "controls", "quantity", "input"]

  connect() {
    this.refresh = this.refresh.bind(this)
    window.addEventListener("pharmacy:cart-changed", this.refresh)
    this.refresh()
  }

  disconnect() { window.removeEventListener("pharmacy:cart-changed", this.refresh) }

  add() { addToCart(this.productIdValue, this.hasInputTarget ? this.inputTarget.value : 1); this.refresh() }
  increase() { setQuantity(this.productIdValue, quantityFor(this.productIdValue) + 1) }
  decrease() { const quantity = quantityFor(this.productIdValue); quantity > 1 ? setQuantity(this.productIdValue, quantity - 1) : toast("الحد الأدنى للكمية قطعة واحدة", "information") }
  update() { setQuantity(this.productIdValue, this.inputTarget.value) }

  refresh() {
    const quantity = quantityFor(this.productIdValue)
    if (this.hasQuantityTarget) this.quantityTarget.textContent = quantity
    if (this.hasInputTarget && quantity > 0) this.inputTarget.value = quantity
    if (this.hasAddTarget && this.hasControlsTarget) {
      this.addTarget.classList.toggle("hidden", quantity > 0)
      this.controlsTarget.classList.toggle("hidden", quantity === 0)
    }
  }
}
