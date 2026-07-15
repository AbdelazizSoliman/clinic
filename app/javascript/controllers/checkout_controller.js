import { Controller } from "@hotwired/stimulus"
import { validCartItems, subtotalCents, formatMoney, checkoutItemMarkup } from "lib/shopping_store"

export default class extends Controller {
  static targets = ["items", "subtotal", "prescription", "empty", "form", "completion", "firstError"]
  connect() {
    this.refresh = this.refresh.bind(this); window.addEventListener("pharmacy:cart-changed", this.refresh); this.refresh()
  }
  disconnect() { window.removeEventListener("pharmacy:cart-changed", this.refresh) }
  refresh() {
    const items = validCartItems(); this.itemsTarget.innerHTML = items.map(item => checkoutItemMarkup(item)).join("")
    this.subtotalTarget.textContent = formatMoney(subtotalCents()); this.prescriptionTarget.classList.toggle("hidden", !items.some(item => item.product.prescription)); this.emptyTarget.classList.toggle("hidden", items.length > 0); this.formTarget.classList.toggle("hidden", items.length === 0)
  }
  submit(event) {
    event.preventDefault()
    if (!this.formTarget.checkValidity()) { this.formTarget.reportValidity(); return }
    this.completionTarget.classList.remove("hidden"); document.body.classList.add("overflow-hidden"); this.completionTarget.querySelector("button").focus()
  }
  close() { this.completionTarget.classList.add("hidden"); document.body.classList.remove("overflow-hidden") }
}
